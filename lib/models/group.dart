import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant un groupe de discussion
class Group {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final List<String> memberIds;
  final List<String> adminIds;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  // Métadonnées
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastSenderId;
  final Map<String, int> unreadCounts; // userId -> count

  Group({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.memberIds,
    required this.adminIds,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSenderId,
    this.unreadCounts = const {},
  });

  /// Crée un Group depuis Firestore
  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Group(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      photoUrl: data['photoUrl'],
      memberIds: List<String>.from(data['memberIds'] ?? []),
      adminIds: List<String>.from(data['adminIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      lastSenderId: data['lastSenderId'],
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
    );
  }

  /// Convertit en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'memberIds': memberIds,
      'adminIds': adminIds,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'createdBy': createdBy,
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageTime != null)
        'lastMessageTime': Timestamp.fromDate(lastMessageTime!),
      if (lastSenderId != null) 'lastSenderId': lastSenderId,
      'unreadCounts': unreadCounts,
    };
  }

  /// Vérifie si un utilisateur est admin
  bool isAdmin(String userId) {
    return adminIds.contains(userId);
  }

  /// Vérifie si un utilisateur est membre
  bool isMember(String userId) {
    return memberIds.contains(userId);
  }

  /// Obtient le nombre de messages non lus pour un utilisateur
  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  /// Copie avec modifications
  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? photoUrl,
    List<String>? memberIds,
    List<String>? adminIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastSenderId,
    Map<String, int>? unreadCounts,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      memberIds: memberIds ?? this.memberIds,
      adminIds: adminIds ?? this.adminIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      unreadCounts: unreadCounts ?? this.unreadCounts,
    );
  }
}
