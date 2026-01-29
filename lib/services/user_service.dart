import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

/// Service pour gérer les utilisateurs dans Firestore
class UserService {
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  /// Crée le profil d'un nouvel utilisateur avec TOUS les champs requis
  Future<void> createUserProfile({
    required String userId,
    required String displayName,
    required String email,
  }) async {
    await _usersCollection.doc(userId).set({
      'displayName': displayName,
      'email': email,
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'notificationsEnabled': true,
      'typingIn': {},
      'unreadCount': 0,
      'fcmToken': null,
      'photoUrl': null,
      'status': null,
    });
  }

  /// Met l'utilisateur en ligne
  Future<void> setUserOnline(String userId) async {
    await _usersCollection.doc(userId).set({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Met l'utilisateur hors ligne
  Future<void> setUserOffline(String userId) async {
    await _usersCollection.doc(userId).set({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// S'assure que le profil utilisateur existe avec TOUS les champs
  Future<void> ensureUserProfile({
    required String userId,
    required String displayName,
    required String email,
  }) async {
    await _usersCollection.doc(userId).set({
      'displayName': displayName,
      'email': email,
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
      'notificationsEnabled': true,
      'typingIn': {},
      'unreadCount': 0,
    }, SetOptions(merge: true));
  }

  /// Stream des utilisateurs en ligne (filtre côté client)
  Stream<List<AppUser>> getOnlineUsers(String currentUserId) {
    return _usersCollection.snapshots().map((snapshot) {
      final users = snapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) => AppUser.fromFirestore(doc))
          .where((user) => user.isOnline) // Filtre côté client
          .toList();

      // Tri par dernière activité
      users.sort((a, b) {
        final aTime = a.lastSeen ?? DateTime(1970);
        final bTime = b.lastSeen ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      return users;
    });
  }

  /// Stream de tous les utilisateurs (sauf l'utilisateur courant)
  /// Tri côté client pour éviter les index Firestore
  Stream<List<AppUser>> getAllUsers(String currentUserId) {
    return _usersCollection.snapshots().map((snapshot) {
      final users = snapshot.docs
          .where((doc) => doc.id != currentUserId)
          .map((doc) => AppUser.fromFirestore(doc))
          .toList();

      // Tri complet côté client
      users.sort((a, b) {
        // 1. En ligne d'abord
        if (a.isOnline != b.isOnline) {
          return a.isOnline ? -1 : 1;
        }
        // 2. Puis par dernière activité
        final aTime = a.lastSeen ?? DateTime(1970);
        final bTime = b.lastSeen ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      return users;
    });
  }

  /// Récupère un utilisateur par son ID
  Future<AppUser?> getUserById(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    if (doc.exists) {
      return AppUser.fromFirestore(doc);
    }
    return null;
  }
}
