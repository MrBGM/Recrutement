import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle de message complet (style WhatsApp)
class Message {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime timestamp;

  // Statut du message
  final MessageStatus status;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  // Type de message
  final MessageType type;
  final String? mediaUrl; // Pour images/fichiers
  final String? thumbnailUrl; // Miniature pour images
  final Map<String, dynamic>? mediaMetadata; // Taille, dimensions, etc.

  // Suppression et édition
  final bool isDeletedForEveryone;
  final List<String> deletedForUsers;
  final bool isEdited;
  final DateTime? editedAt;
  final String? originalContent;

  // Réactions
  final Map<String, String> reactions; // userId -> emoji

  // Réponse à un message
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;
  final bool isGroupMessage;
  final String? groupId;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.deliveredAt,
    this.readAt,
    this.type = MessageType.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaMetadata,
    this.isDeletedForEveryone = false,
    this.deletedForUsers = const [],
    this.isEdited = false,
    this.editedAt,
    this.originalContent,
    this.reactions = const {},
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
    this.isGroupMessage = false,
    this.groupId,
  });

  /// Crée un Message depuis Firestore
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Message(
      id: doc.id,
      content: data['content'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Anonyme',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      type: MessageType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      mediaUrl: data['mediaUrl'],
      thumbnailUrl: data['thumbnailUrl'],
      mediaMetadata: data['mediaMetadata'],
      isDeletedForEveryone: data['isDeletedForEveryone'] ?? false,
      deletedForUsers: List<String>.from(data['deletedForUsers'] ?? []),
      isEdited: data['isEdited'] ?? false,
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      originalContent: data['originalContent'],
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      replyToMessageId: data['replyToMessageId'],
      replyToContent: data['replyToContent'],
      replyToSenderName: data['replyToSenderName'],
      isGroupMessage: data['isGroupMessage'] ?? false,
      groupId: data['groupId'],
    );
  }

  /// Convertit en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.name,
      if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      'type': type.name,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (mediaMetadata != null) 'mediaMetadata': mediaMetadata,
      'isDeletedForEveryone': isDeletedForEveryone,
      'deletedForUsers': deletedForUsers,
      'isEdited': isEdited,
      if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      if (originalContent != null) 'originalContent': originalContent,
      'reactions': reactions,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToContent != null) 'replyToContent': replyToContent,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      'isGroupMessage': isGroupMessage,
      if (groupId != null) 'groupId': groupId,
    };
  }

  /// Vérifie si ce message est supprimé pour un utilisateur donné
  bool isDeletedFor(String userId) {
    return isDeletedForEveryone || deletedForUsers.contains(userId);
  }

  /// Copie avec modifications
  Message copyWith({
    String? id,
    String? content,
    String? senderId,
    String? senderName,
    DateTime? timestamp,
    MessageStatus? status,
    DateTime? deliveredAt,
    DateTime? readAt,
    MessageType? type,
    String? mediaUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? mediaMetadata,
    bool? isDeletedForEveryone,
    List<String>? deletedForUsers,
    bool? isEdited,
    DateTime? editedAt,
    String? originalContent,
    Map<String, String>? reactions,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    bool? isGroupMessage,
    String? groupId,
  }) {
    return Message(
        id: id ?? this.id,
        content: content ?? this.content,
        senderId: senderId ?? this.senderId,
        senderName: senderName ?? this.senderName,
        timestamp: timestamp ?? this.timestamp,
        status: status ?? this.status,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        readAt: readAt ?? this.readAt,
        type: type ?? this.type,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        mediaMetadata: mediaMetadata ?? this.mediaMetadata,
        isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
        deletedForUsers: deletedForUsers ?? this.deletedForUsers,
        isEdited: isEdited ?? this.isEdited,
        editedAt: editedAt ?? this.editedAt,
        originalContent: originalContent ?? this.originalContent,
        reactions: reactions ?? this.reactions,
        replyToMessageId: replyToMessageId ?? this.replyToMessageId,
        replyToContent: replyToContent ?? this.replyToContent,
        replyToSenderName: replyToSenderName ?? this.replyToSenderName,
        isGroupMessage: isGroupMessage ?? this.isGroupMessage,
        groupId: groupId ?? this.groupId);
  }
}

/// Statut du message (style WhatsApp)
enum MessageStatus {
  sending, // En cours d'envoi
  sent, // Envoyé (✓)
  delivered, // Délivré (✓✓)
  read, // Lu (✓✓ bleu)
  failed, // Échec
}

/// Type de message
enum MessageType {
  text, // Message texte
  image, // Image
  video, // Vidéo
  audio, // Audio
  document, // Document (PDF, etc.)
  location, // Localisation
}
