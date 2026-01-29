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
// 1. NOTIFICATION NOUVEAU MESSAGE
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

      // Récupérer la conversation
      const conversationRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId);
      
      const conversationDoc = await conversationRef.get();
      
      if (!conversationDoc.exists) {
        console.log(`Conversation ${conversationId} non trouvée`);
        return null;
      }

      const conversation = conversationDoc.data();
      
      // ✅ Déterminer les participants
      let participants: string[] = [];
      
      // Pour conversations 1-1 (format: userId1_userId2)
      if (conversationId.includes('_')) {
        participants = conversationId.split('_');
      } 
      // Pour groupes (avec participantIds)
      else if (conversation?.participantIds) {
        participants = conversation.participantIds;
      }
      
      // Filtrer l'expéditeur
      const recipients = participants.filter((uid: string) => uid !== message.senderId);

      // Préparer les mises à jour
      const batch = admin.firestore().batch();

      for (const recipientId of recipients) {
        // Récupérer l'utilisateur
        const userRef = admin.firestore().collection('users').doc(recipientId);
        const userDoc = await userRef.get();

        if (!userDoc.exists) continue;

        const userData = userDoc.data();
        
        // Vérifier les préférences
        if (userData?.notificationsEnabled === false) continue;
        
        const fcmToken = userData?.fcmToken;
        if (!fcmToken) continue;

        // Envoyer notification
        const notification: admin.messaging.Message = {
          token: fcmToken,
          notification: {
            title: message.senderName || 'Nouveau message',
            body: message.content?.length > 100 
              ? `${message.content.substring(0, 100)}...`
              : message.content || '',
          },
          data: {
            type: 'new_message',
            conversationId,
            messageId: snapshot.id,
            senderId: message.senderId,
            senderName: message.senderName,
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
          console.log(`✅ Notification envoyée à ${recipientId}`);
        } catch (error: any) {
          console.error(`❌ Erreur pour ${recipientId}:`, error.message);
          
          // Nettoyer les tokens invalides
          if (error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered') {
            await userRef.update({
              fcmToken: admin.firestore.FieldValue.delete()
            });
          }
        }

        // Incrémenter compteur non lu
        batch.update(conversationRef, {
          [`unreadCounts.${recipientId}`]: admin.firestore.FieldValue.increment(1)
        });
      }

      // Mettre à jour dernière activité
      batch.update(conversationRef, {
        lastMessage: message.content,
        lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
        lastSenderId: message.senderId
      });

      await batch.commit();
      console.log(`✅ Traitement terminé pour ${conversationId}`);

    } catch (error: any) {
      console.error('❌ Erreur dans onMessageCreated:', error);
    }

    return null;
  });

// ========================================
// 2. MARQUER COMME LU (avec CORS)
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
    const { conversationId } = req.body.data || req.body;

    if (!conversationId) {
      res.status(400).json({ error: 'conversationId manquant' });
      return;
    }

    // Mettre à jour le compteur
    await admin.firestore()
      .collection('conversations')
      .doc(conversationId)
      .set({
        [`unreadCounts.${userId}`]: 0
      }, { merge: true });

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
// 3. CRÉATION AUTOMATIQUE CONVERSATION
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