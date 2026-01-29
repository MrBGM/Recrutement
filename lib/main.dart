import 'package:ai_chat/screens/home_screen.dart';
import 'package:ai_chat/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/users_list_screen.dart';
import 'screens/chat_screen.dart';
import 'providers/chat_provider.dart';
import 'models/app_user.dart';
import 'services/user_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // AJOUTER CET IMPORT

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialiser les notifications POUR LE WEB SEULEMENT
  if (kIsWeb) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await NotificationService().initialize(userId);
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

/// Gère l'état d'authentification et la navigation
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final UserService _userService = UserService();
  AppUser? _selectedUser;
  String? _lastOnlineUserId; // Pour éviter les appels répétés de setUserOnline

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialiser les notifications pour Web dans initState aussi
    if (kIsWeb) {
      _initializeWebNotifications();
    }
  }

  Future<void> _initializeWebNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await NotificationService().initialize(user.uid);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        _userService.setUserOffline(user.uid);
      } else if (state == AppLifecycleState.resumed) {
        _userService.setUserOnline(user.uid);
      }
    }
  }

  void _selectUser(AppUser user) {
    setState(() {
      _selectedUser = user;
    });
  }

  void _clearSelectedUser() {
    setState(() {
      _selectedUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Chargement
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Non connecté → écran de login
        if (!snapshot.hasData || snapshot.data == null) {
          _lastOnlineUserId = null; // Réinitialiser lors de la déconnexion
          return const LoginScreen();
        }

        final firebaseUser = snapshot.data!;

        // Mettre l'utilisateur en ligne (une seule fois par session)
        if (_lastOnlineUserId != firebaseUser.uid) {
          _lastOnlineUserId = firebaseUser.uid;
          _userService.setUserOnline(firebaseUser.uid);

          // Initialiser les notifications quand l'utilisateur se connecte
          if (kIsWeb) {
            NotificationService().initialize(firebaseUser.uid);
          }
        }

        // Connecté mais pas de conversation sélectionnée → liste des utilisateurs
        if (_selectedUser == null) {
          return const HomeScreen();
        }

        // Conversation sélectionnée → écran de chat
        return ChangeNotifierProvider(
          key: ValueKey(_selectedUser!.id),
          create: (_) => ChatProvider(
            currentUserId: firebaseUser.uid,
            currentUserName: firebaseUser.displayName ?? 'Utilisateur',
            otherUser: _selectedUser!,
          ),
          child: ChatScreen(onBack: _clearSelectedUser),
        );
      },
    );
  }
}
