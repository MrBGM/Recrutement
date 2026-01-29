import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

// ========================================
// CONFIGURATION CORS
// ========================================

const corsOptions = {
  origin: true, // ✅ Permet toutes les origines en développement
  credentials: true,
};

// Helper pour gérer CORS manuellement
function handleCors(req: functions.https.Request, res: functions.Response): boolean {
  // Définir les headers CORS
  res.set('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Credentials', 'true');
  res.set('Access-Control-Max-Age', '3600');

  // Répondre immédiatement aux requêtes OPTIONS (preflight)
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return true;
  }

  return false;
}

// ========================================
// HELPER - ENVOI DE NOTIFICATION
// ========================================

async function sendNotificationToUser(
  userId: string,
  senderId: string,
  senderName: string,
  content: string,
  conversationId: string,
  messageId: string,
  isGroup: boolean = false,
  groupName?: string
): Promise<void> {
  const userRef = admin.firestore().collection('users').doc(userId);
  const userDoc = await userRef.get();

  if (!userDoc.exists) return;

  const userData = userDoc.data();

  // Vérifier les préférences
  if (userData?.notificationsEnabled === false) return;

  const fcmToken = userData?.fcmToken;
  if (!fcmToken) return;

  // Construire le titre de la notification
  const title = isGroup && groupName
    ? `${senderName} dans ${groupName}`
    : senderName || 'Nouveau message';

  // Construire le contenu
  const body = content?.length > 100
    ? `${content.substring(0, 100)}...`
    : content || '';

  const notification: admin.messaging.Message = {
    token: fcmToken,
    notification: {
      title,
      body,
    },
    data: {
      type: isGroup ? 'group_message' : 'new_message',
      conversationId,
      messageId,
      senderId,
      senderName,
      ...(isGroup && groupName ? { groupName } : {}),
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    webpush: {
      fcmOptions: {
        link: `https://ai-chat-23aa5.web.app/?conversation=${conversationId}`
      }
    },
    android: {
      priority: 'high'
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1
        }
      }
    }
  };

  try {
    await admin.messaging().send(notification);
    console.log(`✅ Notification envoyée à ${userId}`);
  } catch (error: any) {
    console.error(`❌ Erreur pour ${userId}:`, error.message);

    // Nettoyer les tokens invalides
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      await userRef.update({
        fcmToken: admin.firestore.FieldValue.delete()
      });
    }
  }
}

// ========================================
// 1. NOTIFICATION NOUVEAU MESSAGE (1-1)
// ========================================

export const onMessageCreated = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      const message = snapshot.data();
      const { conversationId } = context.params;

      // Ignorer si message supprimé
      if (message.isDeletedForEveryone ||
          (message.deletedForUsers && message.deletedForUsers.length > 0)) {
        return null;
      }

      console.log(`📬 Nouveau message dans conversation: ${conversationId}`);

      // Récupérer la conversation
      const conversationRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId);

      const conversationDoc = await conversationRef.get();

      // ✅ Déterminer les participants
      let participants: string[] = [];

      // Pour conversations 1-1 (format: userId1_userId2)
      if (conversationId.includes('_') && conversationId.split('_').length === 2) {
        participants = conversationId.split('_');
      }
      // Pour groupes (avec participantIds dans la conversation)
      else if (conversationDoc.exists) {
        const conversation = conversationDoc.data();
        if (conversation?.participantIds) {
          participants = conversation.participantIds;
        }
      }

      // Filtrer l'expéditeur
      const recipients = participants.filter((uid: string) => uid !== message.senderId);

      // Préparer les mises à jour
      const batch = admin.firestore().batch();

      for (const recipientId of recipients) {
        // Envoyer notification
        await sendNotificationToUser(
          recipientId,
          message.senderId,
          message.senderName,
          message.content,
          conversationId,
          snapshot.id,
          false
        );

        // Incrémenter compteur non lu (seulement si conversation existe)
        if (conversationDoc.exists) {
          batch.update(conversationRef, {
            [`unreadCounts.${recipientId}`]: admin.firestore.FieldValue.increment(1)
          });
        }
      }

      // Mettre à jour dernière activité (seulement si conversation existe)
      if (conversationDoc.exists) {
        batch.update(conversationRef, {
          lastMessage: message.content,
          lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
          lastSenderId: message.senderId
        });
      }

      await batch.commit();
      console.log(`✅ Traitement terminé pour conversation ${conversationId}`);

    } catch (error: any) {
      console.error('❌ Erreur dans onMessageCreated:', error);
    }

    return null;
  });

// ========================================
// 2. NOTIFICATION NOUVEAU MESSAGE (GROUPE)
// ========================================

export const onGroupMessageCreated = functions.firestore
  .document('groups/{groupId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      const message = snapshot.data();
      const { groupId } = context.params;

      // Ignorer si message supprimé
      if (message.isDeletedForEveryone ||
          (message.deletedForUsers && message.deletedForUsers.length > 0)) {
        return null;
      }

      console.log(`📬 Nouveau message dans groupe: ${groupId}`);

      // Récupérer le groupe
      const groupRef = admin.firestore().collection('groups').doc(groupId);
      const groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        console.log(`❌ Groupe ${groupId} non trouvé`);
        return null;
      }

      const groupData = groupDoc.data();
      const groupName = groupData?.name || 'Groupe';
      const memberIds: string[] = groupData?.memberIds || [];

      // Filtrer l'expéditeur
      const recipients = memberIds.filter((uid: string) => uid !== message.senderId);

      console.log(`📱 Envoi de notifications à ${recipients.length} membres`);

      // Envoyer notifications à tous les membres
      for (const recipientId of recipients) {
        await sendNotificationToUser(
          recipientId,
          message.senderId,
          message.senderName,
          message.content,
          groupId,
          snapshot.id,
          true,
          groupName
        );
      }

      console.log(`✅ Traitement terminé pour groupe ${groupId}`);

    } catch (error: any) {
      console.error('❌ Erreur dans onGroupMessageCreated:', error);
    }

    return null;
  });

// ========================================
// 3. MARQUER COMME LU (avec CORS)
// ========================================

export const markAsRead = functions.https.onRequest(async (req, res) => {
  // ✅ Gérer CORS
  if (handleCors(req, res)) return;

  try {
    // Vérifier l'authentification
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Non authentifié' });
      return;
    }

    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const userId = decodedToken.uid;

    // Récupérer conversationId
    const { conversationId, isGroup } = req.body.data || req.body;

    if (!conversationId) {
      res.status(400).json({ error: 'conversationId manquant' });
      return;
    }

    // Mettre à jour le compteur selon le type
    if (isGroup) {
      // Pour les groupes, on ne gère pas les compteurs non lus pour l'instant
      // Car les messages sont dans groups/{groupId}/messages
      console.log(`Marqué comme lu pour groupe ${conversationId}`);
    } else {
      await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .set({
          [`unreadCounts.${userId}`]: 0
        }, { merge: true });
    }

    res.status(200).json({
      result: { success: true }
    });

  } catch (error: any) {
    console.error('Erreur markAsRead:', error);
    res.status(500).json({
      error: error.message
    });
  }
});

// ========================================
// 4. CRÉATION AUTOMATIQUE CONVERSATION
// ========================================

export const onConversationCreated = functions.firestore
  .document('conversations/{conversationId}')
  .onCreate(async (snapshot, context) => {
    const conversation = snapshot.data();

    // S'assurer que les compteurs non lus existent pour tous les participants
    if (conversation.participantIds && !conversation.unreadCounts) {
      const unreadCounts: { [key: string]: number } = {};

      conversation.participantIds.forEach((userId: string) => {
        unreadCounts[userId] = 0;
      });

      await snapshot.ref.update({ unreadCounts });
    }

    return null;
  });

// ========================================
// 5. NETTOYAGE UTILISATEUR DÉCONNECTÉ
// ========================================

export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  try {
    const userId = user.uid;
    console.log(`🗑️ Nettoyage des données de l'utilisateur ${userId}`);

    // Supprimer le document utilisateur
    await admin.firestore().collection('users').doc(userId).delete();

    console.log(`✅ Données supprimées pour ${userId}`);
  } catch (error: any) {
    console.error('❌ Erreur lors du nettoyage:', error);
  }
});
