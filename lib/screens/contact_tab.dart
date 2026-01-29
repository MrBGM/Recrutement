import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';

/// Onglet Contacts avec groupes et listes de diffusion
class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  final UserService _userService = UserService();
  final Set<String> _selectedContactIds = {};
  bool _isSelectingForGroup = false;
  bool _isSelectingForBroadcast = false;

  void _toggleContactSelection(String userId) {
    setState(() {
      if (_selectedContactIds.contains(userId)) {
        _selectedContactIds.remove(userId);
      } else {
        _selectedContactIds.add(userId);
      }
    });
  }

  void _startGroupCreation() {
    setState(() {
      _isSelectingForGroup = true;
      _selectedContactIds.clear();
    });
  }

  void _startBroadcastCreation() {
    setState(() {
      _isSelectingForBroadcast = true;
      _selectedContactIds.clear();
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectingForGroup = false;
      _isSelectingForBroadcast = false;
      _selectedContactIds.clear();
    });
  }

  void _createGroup() {
    if (_selectedContactIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Sélectionnez au moins 2 contacts pour créer un groupe'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showGroupNameDialog();
  }

  void _createBroadcastList() {
    if (_selectedContactIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez au moins 1 contact'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _showBroadcastNameDialog();
  }

  void _showGroupNameDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau groupe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du groupe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedContactIds.length} participants sélectionnés',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                _finalizeGroupCreation(name);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _showBroadcastNameDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle liste de diffusion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la liste',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.campaign),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedContactIds.length} destinataires',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                _finalizeBroadcastCreation(name);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _finalizeGroupCreation(String groupName) {
    // TODO: Créer le groupe dans Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Groupe "$groupName" créé avec ${_selectedContactIds.length} membres'),
        backgroundColor: Colors.green,
      ),
    );
    _cancelSelection();
  }

  void _finalizeBroadcastCreation(String listName) {
    // TODO: Créer la liste de diffusion dans Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Liste "$listName" créée avec ${_selectedContactIds.length} destinataires'),
        backgroundColor: Colors.green,
      ),
    );
    _cancelSelection();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(child: Text('Non connecté'));
    }

    final isSelecting = _isSelectingForGroup || _isSelectingForBroadcast;

    return Scaffold(
      body: Column(
        children: [
          // Header avec options
          if (!isSelecting)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Column(
                children: [
                  // Boutons d'actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _startGroupCreation,
                          icon: const Icon(Icons.group_add),
                          label: const Text('Nouveau groupe'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _startBroadcastCreation,
                          icon: const Icon(Icons.campaign),
                          label: const Text('Liste de diffusion'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Header de sélection
          if (isSelecting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _cancelSelection,
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isSelectingForGroup
                          ? 'Sélectionner les membres du groupe'
                          : 'Sélectionner les destinataires',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Text(
                    '${_selectedContactIds.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _isSelectingForGroup
                        ? _createGroup
                        : _createBroadcastList,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Suivant'),
                  ),
                ],
              ),
            ),

          // Liste des contacts
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: _userService.getAllUsers(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                final users = snapshot.data ?? [];

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.contacts_outlined,
                          size: 64,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun contact',
                          style: TextStyle(
                            color: colorScheme.outline,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedContactIds.contains(user.id);

                    return _ContactTile(
                      user: user,
                      isSelectionMode: isSelecting,
                      isSelected: isSelected,
                      onTap: isSelecting
                          ? () => _toggleContactSelection(user.id)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile représentant un contact
class _ContactTile extends StatelessWidget {
  final AppUser user;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ContactTile({
    required this.user,
    required this.isSelectionMode,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          // Indicateur en ligne
          if (user.isOnline && !isSelectionMode)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        user.displayName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        user.isOnline ? 'En ligne' : _formatLastSeen(user.lastSeen),
        style: TextStyle(
          color: user.isOnline ? Colors.green : colorScheme.outline,
          fontSize: 13,
        ),
      ),
      trailing: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onTap?.call(),
              activeColor: colorScheme.primary,
            )
          : Icon(
              Icons.chat_bubble_outline,
              color: colorScheme.primary,
            ),
    );
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Hors ligne';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return 'Il y a ${difference.inDays}j';
    }
  }
}
