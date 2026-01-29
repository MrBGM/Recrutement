import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/group.dart';
import '../models/broadcast_list.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import 'group_chat_screen.dart';

/// Onglet Contacts avec groupes et listes de diffusion
class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final FirestoreService _firestoreService = FirestoreService();
  final Set<String> _selectedContactIds = {};
  bool _isSelectingForGroup = false;
  bool _isSelectingForBroadcast = false;
  bool _isLoading = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
    final descriptionController = TextEditingController();

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
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
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
                _finalizeGroupCreation(name, descriptionController.text.trim());
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

  /// Crée le groupe dans Firestore
  Future<void> _finalizeGroupCreation(
      String groupName, String description) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      // Ajouter l'utilisateur courant aux membres
      final allMembers = [..._selectedContactIds, currentUser.uid];

      final groupId = await _firestoreService.createGroup(
        name: groupName,
        description: description.isNotEmpty ? description : null,
        createdBy: currentUser.uid,
        memberIds: allMembers,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Groupe "$groupName" créé avec ${_selectedContactIds.length} membres'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Ouvrir',
              textColor: Colors.white,
              onPressed: () => _openGroup(groupId),
            ),
          ),
        );
        _cancelSelection();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Crée la liste de diffusion dans Firestore
  Future<void> _finalizeBroadcastCreation(String listName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      await _firestoreService.createBroadcastList(
        name: listName,
        createdBy: currentUser.uid,
        recipientIds: _selectedContactIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Liste "$listName" créée avec ${_selectedContactIds.length} destinataires'),
            backgroundColor: Colors.green,
          ),
        );
        _cancelSelection();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Ouvre un groupe
  void _openGroup(String groupId) async {
    final group = await _firestoreService.getGroupById(groupId);
    if (group != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupChatScreen(group: group),
        ),
      );
    }
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
          // Header avec options ou tabs
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
                  const SizedBox(height: 12),
                  // Tabs
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Contacts'),
                      Tab(text: 'Groupes'),
                      Tab(text: 'Diffusions'),
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
                    onPressed: _isLoading
                        ? null
                        : (_isSelectingForGroup
                            ? _createGroup
                            : _createBroadcastList),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: const Text('Suivant'),
                  ),
                ],
              ),
            ),

          // Contenu principal
          Expanded(
            child: isSelecting
                ? _buildContactsList(currentUser.uid, isSelecting: true)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildContactsList(currentUser.uid, isSelecting: false),
                      _buildGroupsList(currentUser.uid),
                      _buildBroadcastsList(currentUser.uid),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Liste des contacts
  Widget _buildContactsList(String currentUserId,
      {required bool isSelecting}) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<AppUser>>(
      stream: _userService.getAllUsers(currentUserId),
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
    );
  }

  /// Liste des groupes
  Widget _buildGroupsList(String currentUserId) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Group>>(
      stream: _firestoreService.getUserGroups(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final groups = snapshot.data ?? [];

        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.group_outlined,
                  size: 64,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun groupe',
                  style: TextStyle(
                    color: colorScheme.outline,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _startGroupCreation,
                  icon: const Icon(Icons.add),
                  label: const Text('Créer un groupe'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            return _GroupTile(
              group: group,
              currentUserId: currentUserId,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupChatScreen(group: group),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Liste des diffusions
  Widget _buildBroadcastsList(String currentUserId) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<BroadcastList>>(
      stream: _firestoreService.getUserBroadcastLists(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final broadcasts = snapshot.data ?? [];

        if (broadcasts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 64,
                  color: colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune liste de diffusion',
                  style: TextStyle(
                    color: colorScheme.outline,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _startBroadcastCreation,
                  icon: const Icon(Icons.add),
                  label: const Text('Créer une liste'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: broadcasts.length,
          itemBuilder: (context, index) {
            final broadcast = broadcasts[index];
            return _BroadcastTile(
              broadcast: broadcast,
              onTap: () => _showBroadcastOptions(broadcast),
            );
          },
        );
      },
    );
  }

  /// Affiche les options pour une liste de diffusion
  void _showBroadcastOptions(BroadcastList broadcast) {
    final messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.campaign),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        broadcast.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${broadcast.recipientIds.length} destinataires',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteBroadcast(broadcast),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message à diffuser',
                border: OutlineInputBorder(),
                hintText: 'Tapez votre message...',
              ),
              maxLines: 3,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final content = messageController.text.trim();
                  if (content.isNotEmpty) {
                    Navigator.pop(context);
                    await _sendBroadcastMessage(broadcast, content);
                  }
                },
                icon: const Icon(Icons.send),
                label: const Text('Envoyer à tous'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Envoie un message à une liste de diffusion
  Future<void> _sendBroadcastMessage(
      BroadcastList broadcast, String content) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await _firestoreService.sendBroadcastMessage(
        broadcastId: broadcast.id,
        content: content,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 'Utilisateur',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Message envoyé à ${broadcast.recipientIds.length} destinataires'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Supprime une liste de diffusion
  Future<void> _deleteBroadcast(BroadcastList broadcast) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la liste'),
        content:
            Text('Voulez-vous supprimer la liste "${broadcast.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Navigator.pop(context); // Ferme le bottom sheet
      await _firestoreService.deleteBroadcastList(broadcast.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Liste supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
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
      selectedTileColor: colorScheme.primaryContainer.withAlpha(77),
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

/// Tuile représentant un groupe
class _GroupTile extends StatelessWidget {
  final Group group;
  final String currentUserId;
  final VoidCallback onTap;

  const _GroupTile({
    required this.group,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unreadCount = group.unreadCounts[currentUserId] ?? 0;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.secondaryContainer,
        backgroundImage:
            group.photoUrl != null ? NetworkImage(group.photoUrl!) : null,
        child: group.photoUrl == null
            ? Text(
                group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                style: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : null,
      ),
      title: Text(
        group.name,
        style: TextStyle(
          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        group.lastMessage ?? '${group.memberIds.length} membres',
        style: TextStyle(
          color: unreadCount > 0 ? colorScheme.onSurface : colorScheme.outline,
          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: unreadCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Icon(
              group.adminIds.contains(currentUserId)
                  ? Icons.admin_panel_settings
                  : Icons.group,
              color: colorScheme.outline,
              size: 20,
            ),
    );
  }
}

/// Tuile représentant une liste de diffusion
class _BroadcastTile extends StatelessWidget {
  final BroadcastList broadcast;
  final VoidCallback onTap;

  const _BroadcastTile({
    required this.broadcast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.tertiaryContainer,
        child: Icon(
          Icons.campaign,
          color: colorScheme.onTertiaryContainer,
        ),
      ),
      title: Text(
        broadcast.name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        '${broadcast.recipientIds.length} destinataires',
        style: TextStyle(
          color: colorScheme.outline,
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.send,
        color: colorScheme.primary,
      ),
    );
  }
}
