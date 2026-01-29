import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant les métadonnées d'une conversation
class Conversation {
  final String id;
  final List<String> participantIds;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastSenderId;

  // Compteurs de messages non lus par utilisateur
  final Map<String, int> unreadCounts; // userId -> count

  // Statuts
  final bool isArchived;
  final bool isMuted;
  final bool isPinned;

  // Métadonnées
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Conversation({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSenderId,
    this.unreadCounts = const {},
    this.isArchived = false,
    this.isMuted = false,
    this.isPinned = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Crée une Conversation depuis Firestore
  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      lastSenderId: data['lastSenderId'],
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      isArchived: data['isArchived'] ?? false,
      isMuted: data['isMuted'] ?? false,
      isPinned: data['isPinned'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convertit en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageTime != null)
        'lastMessageTime': Timestamp.fromDate(lastMessageTime!),
      if (lastSenderId != null) 'lastSenderId': lastSenderId,
      'unreadCounts': unreadCounts,
      'isArchived': isArchived,
      'isMuted': isMuted,
      'isPinned': isPinned,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  /// Obtient le nombre de messages non lus pour un utilisateur
  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  /// Réinitialise le compteur non lus pour un utilisateur
  Conversation resetUnreadCount(String userId) {
    final newCounts = Map<String, int>.from(unreadCounts);
    newCounts[userId] = 0;
    return copyWith(unreadCounts: newCounts);
  }

  /// Incrémente le compteur non lus pour un utilisateur
  Conversation incrementUnreadCount(String userId) {
    final newCounts = Map<String, int>.from(unreadCounts);
    newCounts[userId] = (newCounts[userId] ?? 0) + 1;
    return copyWith(unreadCounts: newCounts);
  }

  /// Copie avec modifications
  Conversation copyWith({
    String? id,
    List<String>? participantIds,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastSenderId,
    Map<String, int>? unreadCounts,
    bool? isArchived,
    bool? isMuted,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
