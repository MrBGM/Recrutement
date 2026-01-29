import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant une liste de diffusion
class BroadcastList {
  final String id;
  final String name;
  final List<String> recipientIds;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BroadcastList({
    required this.id,
    required this.name,
    required this.recipientIds,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  /// Crée une BroadcastList depuis Firestore
  factory BroadcastList.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return BroadcastList(
      id: doc.id,
      name: data['name'] ?? '',
      recipientIds: List<String>.from(data['recipientIds'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convertit en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'recipientIds': recipientIds,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  /// Copie avec modifications
  BroadcastList copyWith({
    String? id,
    String? name,
    List<String>? recipientIds,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BroadcastList(
      id: id ?? this.id,
      name: name ?? this.name,
      recipientIds: recipientIds ?? this.recipientIds,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
