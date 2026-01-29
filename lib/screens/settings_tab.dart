import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

/// Onglet Paramètres avec profil et options
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  void _showEditProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: user.displayName);
    final statusController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom d\'affichage',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: statusController,
              decoration: const InputDecoration(
                labelText: 'Statut (bio)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info_outline),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await user.updateDisplayName(newName);
                // TODO: Mettre à jour le statut dans Firestore
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Non connecté'));
    }

    return ListView(
      children: [
        // Header avec photo de profil
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary,
                colorScheme.primaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Photo de profil
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: colorScheme.onPrimary,
                    child: Text(
                      user.displayName?.isNotEmpty == true
                          ? user.displayName![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.primary,
                      child: IconButton(
                        icon: Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: colorScheme.onPrimary,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fonctionnalité à venir'),
                            ),
                          );
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Nom
              Text(
                user.displayName ?? 'Utilisateur',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimary,
                ),
              ),

              const SizedBox(height: 4),

              // Email
              Text(
                user.email ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onPrimary.withOpacity(0.8),
                ),
              ),

              const SizedBox(height: 16),

              // Bouton modifier
              OutlinedButton.icon(
                onPressed: _showEditProfileDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Modifier le profil'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onPrimary,
                  side: BorderSide(color: colorScheme.onPrimary),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Section Compte
        _SectionHeader(title: 'Compte'),
        _SettingsTile(
          icon: Icons.person_outline,
          title: 'Informations personnelles',
          subtitle: 'Nom, bio, photo',
          onTap: _showEditProfileDialog,
        ),
        _SettingsTile(
          icon: Icons.security_outlined,
          title: 'Confidentialité',
          subtitle: 'Qui peut voir mes infos',
          onTap: () {},
        ),

        const Divider(height: 1),

        // Section Notifications
        _SectionHeader(title: 'Notifications'),
        _SettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications push',
          subtitle: 'Messages, appels, groupes',
          trailing: Switch(
            value: true,
            onChanged: (value) {},
          ),
        ),
        _SettingsTile(
          icon: Icons.volume_up_outlined,
          title: 'Sons',
          subtitle: 'Sons de notification',
          onTap: () {},
        ),

        const Divider(height: 1),

        // Section Apparence
        _SectionHeader(title: 'Apparence'),
        _SettingsTile(
          icon: Icons.palette_outlined,
          title: 'Thème',
          subtitle: 'Clair, sombre, auto',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.wallpaper_outlined,
          title: 'Fond d\'écran',
          subtitle: 'Personnaliser l\'arrière-plan',
          onTap: () {},
        ),

        const Divider(height: 1),

        // Section Stockage
        _SectionHeader(title: 'Stockage et données'),
        _SettingsTile(
          icon: Icons.storage_outlined,
          title: 'Gestion du stockage',
          subtitle: 'Gérer les médias et fichiers',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.wifi_outlined,
          title: 'Utilisation des données',
          subtitle: 'Téléchargement automatique',
          onTap: () {},
        ),

        const Divider(height: 1),

        // Section Aide
        _SectionHeader(title: 'Aide'),
        _SettingsTile(
          icon: Icons.help_outline,
          title: 'Centre d\'aide',
          subtitle: 'FAQ et support',
          onTap: () {},
        ),
        _SettingsTile(
          icon: Icons.info_outline,
          title: 'À propos',
          subtitle: 'Version 2.0.0',
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'AI Chat',
              applicationVersion: '2.0.0',
              applicationIcon: const Icon(Icons.chat_bubble, size: 48),
              children: [
                const Text('Application de messagerie avec IA'),
                const SizedBox(height: 8),
                const Text('© 2026 - Tous droits réservés'),
              ],
            );
          },
        ),

        const Divider(height: 1),

        // Bouton déconnexion
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: _showLogoutDialog,
            icon: const Icon(Icons.logout),
            label: const Text('Déconnexion'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

/// Header de section
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Tuile de paramètre
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
