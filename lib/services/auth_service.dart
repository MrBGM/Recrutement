import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

/// Service d'authentification Firebase
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  /// Utilisateur actuellement connecté
  User? get currentUser => _auth.currentUser;

  /// Stream des changements d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Inscription avec email et mot de passe
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ✅ CRÉER le profil avec TOUS les champs requis
      if (credential.user != null) {
        await _userService.createUserProfile(
          userId: credential.user!.uid,
          displayName: displayName,
          email: email,
        );

        // Mettre à jour le displayName dans Firebase Auth
        await credential.user?.updateDisplayName(displayName);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Connexion avec email et mot de passe
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Mettre à jour le statut en ligne et s'assurer que le profil existe
      if (credential.user != null) {
        final user = credential.user!;
        await _userService.ensureUserProfile(
          userId: user.uid,
          displayName: user.displayName ?? email.split('@').first,
          email: email,
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    final userId = currentUser?.uid;
    if (userId != null) {
      await _userService.setUserOffline(userId);
    }
    await _auth.signOut();
  }

  /// Gestion des erreurs Firebase Auth
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Le mot de passe est trop faible (min 6 caractères)';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé';
      case 'invalid-email':
        return 'Email invalide';
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet email';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'user-disabled':
        return 'Ce compte a été désactivé';
      case 'too-many-requests':
        return 'Trop de tentatives, réessayez plus tard';
      default:
        return 'Erreur: ${e.message}';
    }
  }
}
