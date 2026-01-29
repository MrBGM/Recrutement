import 'package:ai_chat/models/broadcast_list.dart';
import 'package:ai_chat/models/group.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import 'dart:async';

/// Service Firestore complet (style WhatsApp) - VERSION CORRIGÉE
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Timers pour le statut d'écriture
  final Map<String, Timer?> _typingTimers = {};

  // ==========================================
  // HELPERS
  // ==========================================

  /// Vérifie si c'est une conversation 1-1
  bool isOneToOneConversation(String conversationId) {
    return conversationId.contains('_') &&
        conversationId.split('_').length == 2;
  }

  /// Obtient l'autre utilisateur dans une conversation 1-1
  String getOtherUserIdInOneToOne(String conversationId, String currentUserId) {
    if (!isOneToOneConversation(conversationId)) {
      throw Exception('Not a one-to-one conversation: $conversationId');
    }

    final ids = conversationId.split('_');
    return ids[0] == currentUserId ? ids[1] : ids[0];
  }

  /// Génère un ID de conversation unique entre deux utilisateurs
  String getConversationId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  /// ✅ NOUVEAU : S'assure que la conversation existe
  Future<void> _ensureConversationExists(
    String conversationId,
    List<String> participantIds,
  ) async {
    final conversationRef =
        _firestore.collection('conversations').doc(conversationId);

    final doc = await conversationRef.get();

    if (!doc.exists) {
      // Créer la conversation si elle n'existe pas
      final conversationData = {
        'participantIds': participantIds,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts': {
          for (var id in participantIds) id: 0,
        },
        'isArchived': false,
        'isMuted': false,
        'isPinned': false,
      };

      await conversationRef.set(conversationData);
      print('✅ Conversation créée: $conversationId');
    }
  }

  // ==========================================
  // MESSAGES - CRUD
  // ==========================================

  /// Stream des messages filtrés (exclut les supprimés pour l'utilisateur)
  Stream<List<Message>> getMessagesStream(
    String conversationId,
    String currentUserId,
  ) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .where((msg) => !msg.isDeletedFor(currentUserId))
          .toList();
    });
  }

  /// Envoie un nouveau message
  Future<String> sendMessage({
    required String conversationId,
    required String content,
    required String senderId,
    required String senderName,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? mediaMetadata,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    bool isGroup = false,
    String? groupId,
  }) async {
    // ✅ S'assurer que la conversation existe
    final participantIds = conversationId.split('_');
    await _ensureConversationExists(conversationId, participantIds);

    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    final messageData = {
      'id': messageRef.id,
      'content': content,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': Timestamp.fromDate(DateTime.now()),
      'status': MessageStatus.sent.name,
      'type': type.name,
      'isDeletedForEveryone': false,
      'deletedForUsers': [],
      'isEdited': false,
      'reactions': {},
      'isGroupMessage': isGroup,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (mediaMetadata != null) 'mediaMetadata': mediaMetadata,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToContent != null) 'replyToContent': replyToContent,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      if (groupId != null) 'groupId': groupId,
    };

    try {
      await messageRef.set(messageData);

      // Mettre à jour les métadonnées
      await _updateConversationMetadata(
        conversationId,
        content: content,
        senderId: senderId,
      );

      return messageRef.id;
    } catch (e) {
      print('❌ Erreur sendMessage: $e');
      rethrow;
    }
  }

  /// Obtient l'autre participant de la conversation
  String _getOtherUserId(String conversationId, String currentUserId) {
    final ids = conversationId.split('_');
    return ids[0] == currentUserId ? ids[1] : ids[0];
  }

  // ==========================================
  // STATUTS DES MESSAGES
  // ==========================================

  /// Marque un message comme délivré
  Future<void> markMessageAsDelivered(
    String conversationId,
    String messageId,
  ) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'status': MessageStatus.delivered.name,
      'deliveredAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marque un message comme lu
  Future<void> markMessageAsRead(
    String conversationId,
    String messageId,
  ) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'status': MessageStatus.read.name,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ CORRIGÉ : Marque tous les messages comme lus (méthode directe sans Cloud Function)
  Future<void> markAllMessagesAsRead(
    String conversationId,
    String currentUserId,
  ) async {
    try {
      // Méthode directe via Firestore
      final snapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('status', whereIn: [
        MessageStatus.sent.name,
        MessageStatus.delivered.name
      ]).get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': MessageStatus.read.name,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Réinitialiser le compteur non lus
      await _resetUnreadCount(conversationId, currentUserId);

      print('✅ Messages marqués comme lus (méthode directe)');
    } catch (e) {
      print('❌ Erreur markAllMessagesAsRead: $e');
    }
  }

  // ==========================================
  // RÉACTIONS
  // ==========================================

  /// Ajoute ou modifie une réaction à un message
  Future<void> addReaction({
    required String conversationId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'reactions.$userId': emoji,
    });
  }

  /// Retire une réaction d'un message
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'reactions.$userId': FieldValue.delete(),
    });
  }

  // ==========================================
  // SUPPRESSION ET ÉDITION
  // ==========================================

  /// Supprime un message pour moi (soft delete)
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedForUsers': FieldValue.arrayUnion([userId]),
    });
  }

  /// Supprime un message pour tous
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isDeletedForEveryone': true,
      'content': 'Ce message a été supprimé',
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Édite un message
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newContent,
  }) async {
    final messageDoc = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .get();

    if (!messageDoc.exists) return;

    final originalContent = messageDoc.data()?['content'] ?? '';

    await messageDoc.reference.update({
      'content': newContent,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
      'originalContent': originalContent,
    });
  }

  // ==========================================
  // GROUPES
  // ==========================================

  /// Crée un nouveau groupe
  /// Crée un nouveau groupe - VERSION AVEC LOGS
  Future<String> createGroup({
    required String name,
    required String createdBy,
    String? description,
    String? photoUrl,
    required List<String> memberIds,
  }) async {
    final groupRef = _firestore.collection('groups').doc();

    print('🔄 Tentative de création de groupe...');
    print('📝 Données à envoyer:');
    print('  - ID: ${groupRef.id}');
    print('  - Nom: $name');
    print('  - Créé par: $createdBy');
    print('  - Membres: $memberIds');
    print('  - Admins: [$createdBy]');

    final groupData = {
      'id': groupRef.id,
      'name': name,
      'description': description ?? '',
      'photoUrl': photoUrl ?? '',
      'memberIds': memberIds,
      'adminIds': [createdBy],
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await groupRef.set(groupData);
      print('✅ SUCCÈS: Groupe créé dans Firestore!');
      print('   ID du groupe: ${groupRef.id}');
      print('   Collection: groups/${groupRef.id}');

      // Vérifier que le document existe
      final doc = await groupRef.get();
      print('   Document existe: ${doc.exists}');

      return groupRef.id;
    } catch (e, stackTrace) {
      print('❌ ERREUR lors de la création:');
      print('   Type: ${e.runtimeType}');
      print('   Message: $e');

      if (e is FirebaseException) {
        print('   Code Firebase: ${e.code}');
        print('   Message Firebase: ${e.message}');
      }

      print('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Récupère les groupes d'un utilisateur
  Stream<List<Group>> getUserGroups(String userId) {
    return _firestore
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList();
    });
  }

  /// Récupère un groupe par son ID
  Future<Group?> getGroupById(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (doc.exists) {
      return Group.fromFirestore(doc);
    }
    return null;
  }

  /// Ajoute un membre au groupe
  Future<void> addGroupMember({
    required String groupId,
    required String userId,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Retire un membre du groupe
  Future<void> removeGroupMember({
    required String groupId,
    required String userId,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Nomme un admin
  Future<void> promoteToAdmin({
    required String groupId,
    required String userId,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'adminIds': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Retire un admin
  Future<void> demoteFromAdmin({
    required String groupId,
    required String userId,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'adminIds': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Met à jour les informations du groupe
  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) {
      updates['name'] = name;
    }

    if (description != null) {
      updates['description'] = description;
    }

    if (photoUrl != null) {
      updates['photoUrl'] = photoUrl;
    }

    await _firestore.collection('groups').doc(groupId).update(updates);
  }

  // ==========================================
  // LISTES DE DIFFUSION
  // ==========================================

  /// Crée une nouvelle liste de diffusion
  Future<String> createBroadcastList({
    required String name,
    required String createdBy,
    required List<String> recipientIds,
  }) async {
    final broadcastRef = _firestore.collection('broadcasts').doc();

    final broadcast = BroadcastList(
      id: broadcastRef.id,
      name: name,
      recipientIds: recipientIds,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await broadcastRef.set(broadcast.toMap());

    return broadcastRef.id;
  }

  /// Récupère les listes de diffusion d'un utilisateur
  Stream<List<BroadcastList>> getUserBroadcastLists(String userId) {
    return _firestore
        .collection('broadcasts')
        .where('createdBy', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BroadcastList.fromFirestore(doc))
          .toList();
    });
  }

  /// Récupère une liste de diffusion par son ID
  Future<BroadcastList?> getBroadcastListById(String broadcastId) async {
    final doc =
        await _firestore.collection('broadcasts').doc(broadcastId).get();
    if (doc.exists) {
      return BroadcastList.fromFirestore(doc);
    }
    return null;
  }

  /// Envoie un message à une liste de diffusion
  Future<void> sendBroadcastMessage({
    required String broadcastId,
    required String content,
    required String senderId,
    required String senderName,
  }) async {
    final broadcastDoc =
        await _firestore.collection('broadcasts').doc(broadcastId).get();

    if (!broadcastDoc.exists) {
      throw Exception('Liste de diffusion introuvable');
    }

    final broadcast = BroadcastList.fromFirestore(broadcastDoc);

    // Envoyer le message à chaque destinataire individuellement
    for (final recipientId in broadcast.recipientIds) {
      if (recipientId != senderId) {
        // Ne pas s'envoyer à soi-même
        final conversationId = getConversationId(senderId, recipientId);

        await sendMessage(
          conversationId: conversationId,
          content: "[Diffusion: ${broadcast.name}] $content",
          senderId: senderId,
          senderName: senderName,
        );
      }
    }
  }

  /// Met à jour une liste de diffusion
  Future<void> updateBroadcastList({
    required String broadcastId,
    String? name,
    List<String>? recipientIds,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) {
      updates['name'] = name;
    }

    if (recipientIds != null) {
      updates['recipientIds'] = recipientIds;
    }

    await _firestore.collection('broadcasts').doc(broadcastId).update(updates);
  }

  /// Supprime une liste de diffusion
  Future<void> deleteBroadcastList(String broadcastId) async {
    await _firestore.collection('broadcasts').doc(broadcastId).delete();
  }

  // ==========================================
  // STATUT D'ÉCRITURE (TYPING)
  // ==========================================

  /// Indique que l'utilisateur est en train d'écrire
  Future<void> setTypingStatus({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    if (isTyping) {
      await _firestore.collection('users').doc(userId).update({
        'typingIn.$conversationId': FieldValue.serverTimestamp(),
      });

      // Arrêter automatiquement après 5 secondes
      _typingTimers[conversationId]?.cancel();
      _typingTimers[conversationId] = Timer(const Duration(seconds: 5), () {
        setTypingStatus(
          conversationId: conversationId,
          userId: userId,
          isTyping: false,
        );
      });
    } else {
      await _firestore.collection('users').doc(userId).update({
        'typingIn.$conversationId': FieldValue.delete(),
      });
      _typingTimers[conversationId]?.cancel();
    }
  }

  // ==========================================
  // MÉTADONNÉES DE CONVERSATION
  // ==========================================

  /// Met à jour les métadonnées de conversation
  Future<void> _updateConversationMetadata(
    String conversationId, {
    String? content,
    String? senderId,
    String? incrementUnreadFor,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (content != null && senderId != null) {
      data['lastMessage'] = content;
      data['lastMessageTime'] = FieldValue.serverTimestamp();
      data['lastSenderId'] = senderId;
    }

    if (incrementUnreadFor != null) {
      data['unreadCounts.$incrementUnreadFor'] = FieldValue.increment(1);
    }

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .set(data, SetOptions(merge: true));
  }

  /// Réinitialise le compteur de messages non lus
  Future<void> _resetUnreadCount(String conversationId, String userId) async {
    await _firestore.collection('conversations').doc(conversationId).set({
      'unreadCounts.$userId': 0,
    }, SetOptions(merge: true));
  }

  /// Stream des métadonnées de conversation
  Stream<Conversation?> getConversationStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Conversation.fromFirestore(doc);
    });
  }

  // ==========================================
  // SUPPRESSION DE MESSAGES
  // ==========================================

  /// Supprime tous les messages pour l'utilisateur courant (soft delete)
  Future<void> deleteMyMessages({
    required String conversationId,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'deletedForUsers': FieldValue.arrayUnion([userId]),
      });
    }
    await batch.commit();
  }

  /// Supprime définitivement les messages pour l'utilisateur courant (hard delete)
  Future<void> clearMyMessages({
    required String conversationId,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('senderId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Supprime toute la conversation
  Future<void> clearConversation(String conversationId) async {
    // Supprimer tous les messages d'abord
    final messagesSnapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (final doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Supprimer la conversation elle-même
    batch.delete(_firestore.collection('conversations').doc(conversationId));

    await batch.commit();
  }

  // ==========================================
  // UTILITAIRES
  // ==========================================

  /// Récupère les messages récents pour l'IA
  Future<List<Message>> getRecentMessages({
    required String conversationId,
    required String currentUserId,
    int limit = 25,
  }) async {
    final snapshot = await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => Message.fromFirestore(doc))
        .where((msg) => !msg.isDeletedFor(currentUserId))
        .toList()
        .reversed
        .toList();
  }

  /// Nettoie les timers
  void dispose() {
    for (final timer in _typingTimers.values) {
      timer?.cancel();
    }
    _typingTimers.clear();
  }
}
