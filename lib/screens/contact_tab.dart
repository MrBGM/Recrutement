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
  bool _isCreating = false;

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
      _tabController.animateTo(0); // Aller à l'onglet Contacts
    });
  }

  void _startBroadcastCreation() {
    setState(() {
      _isSelectingForBroadcast = true;
      _selectedContactIds.clear();
      _tabController.animateTo(0); // Aller à l'onglet Contacts
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
              '${_selectedContactIds.length} participants sélectionnés (+ vous)',
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
                _finalizeGroupCreation(
                  name,
                  descriptionController.text.trim(),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez entrer un nom de groupe'),
                    backgroundColor: Colors.orange,
                  ),
                );
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
            const SizedBox(height: 4),
            Text(
              'Les messages seront envoyés individuellement',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
                fontStyle: FontStyle.italic,
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
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez entrer un nom de liste'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizeGroupCreation(
      String groupName, String description) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isCreating = true);

    try {
      // Ajouter l'utilisateur courant aux membres
      final memberIds = [currentUser.uid, ..._selectedContactIds.toList()];

      await _firestoreService.createGroup(
        name: groupName,
        createdBy: currentUser.uid,
        memberIds: memberIds,
        description: description.isNotEmpty ? description : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Groupe "$groupName" créé avec ${memberIds.length} membres'),
            backgroundColor: Colors.green,
          ),
        );
        _cancelSelection();
        _tabController.animateTo(1); // Aller à l'onglet Groupes
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création du groupe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _finalizeBroadcastCreation(String listName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isCreating = true);

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
        _tabController.animateTo(2); // Aller à l'onglet Diffusions
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création de la liste: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  void _showSendBroadcastDialog(BroadcastList broadcast) {
    final messageController = TextEditingController();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(broadcast.name)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${broadcast.recipientIds.length} destinataires',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message à diffuser',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final message = messageController.text.trim();
              if (message.isNotEmpty) {
                Navigator.pop(context);
                try {
                  await _firestoreService.sendBroadcastMessage(
                    broadcastId: broadcast.id,
                    content: message,
                    senderId: currentUser.uid,
                    senderName: currentUser.displayName ?? 'Utilisateur',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Message envoyé à ${broadcast.recipientIds.length} destinataires'),
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
            },
            icon: const Icon(Icons.send),
            label: const Text('Envoyer'),
          ),
        ],
      ),
    );
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
          // Header avec boutons de création
          if (!isSelecting)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: Row(
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
                    onPressed: _isCreating ? null : _cancelSelection,
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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedContactIds.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isCreating
                        ? null
                        : (_isSelectingForGroup
                            ? _createGroup
                            : _createBroadcastList),
                    icon: _isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(_isCreating ? 'Création...' : 'Suivant'),
                  ),
                ],
              ),
            ),

          // TabBar pour navigation
          if (!isSelecting)
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.contacts), text: 'Contacts'),
                Tab(icon: Icon(Icons.groups), text: 'Groupes'),
                Tab(icon: Icon(Icons.campaign), text: 'Diffusions'),
              ],
            ),

          // Contenu
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

  Widget _buildContactsList(String currentUserId, {required bool isSelecting}) {
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
              onTap:
                  isSelecting ? () => _toggleContactSelection(user.id) : null,
            );
          },
        );
      },
    );
  }

  Widget _buildGroupsList(String currentUserId) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Group>>(
      stream: _firestoreService.getUserGroups(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Erreur: ${snapshot.error}',
                  style: TextStyle(color: colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final groups = snapshot.data ?? [];

        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.groups_outlined,
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
                Text(
                  'Créez un groupe pour discuter avec plusieurs personnes',
                  style: TextStyle(
                    color: colorScheme.outline,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _startGroupCreation,
                  icon: const Icon(Icons.group_add),
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
            return _GroupTile(group: group);
          },
        );
      },
    );
  }

  Widget _buildBroadcastsList(String currentUserId) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<BroadcastList>>(
      stream: _firestoreService.getUserBroadcastLists(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Erreur: ${snapshot.error}',
                  style: TextStyle(color: colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
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
                Text(
                  'Envoyez le même message à plusieurs personnes',
                  style: TextStyle(
                    color: colorScheme.outline,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _startBroadcastCreation,
                  icon: const Icon(Icons.campaign),
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
              onSend: () => _showSendBroadcastDialog(broadcast),
              onDelete: () => _deleteBroadcast(broadcast),
            );
          },
        );
      },
    );
  }

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
      try {
        await _firestoreService.deleteBroadcastList(broadcast.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Liste supprimée'),
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
        user.status?.isNotEmpty == true
            ? user.status!
            : (user.isOnline ? 'En ligne' : _formatLastSeen(user.lastSeen)),
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

  const _GroupTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colorScheme.secondaryContainer,
        child: Icon(
          Icons.groups,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        group.name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        group.description?.isNotEmpty == true
            ? group.description!
            : '${group.memberIds.length} membres',
        style: TextStyle(
          color: colorScheme.outline,
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.chat_bubble_outline,
        color: colorScheme.primary,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatScreen(
              group: group,
              onBack: () => Navigator.pop(context),
            ),
          ),
        );
      },
    );
  }
}

/// Tuile représentant une liste de diffusion
class _BroadcastTile extends StatelessWidget {
  final BroadcastList broadcast;
  final VoidCallback onSend;
  final VoidCallback onDelete;

  const _BroadcastTile({
    required this.broadcast,
    required this.onSend,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.orange.withOpacity(0.2),
        child: const Icon(
          Icons.campaign,
          color: Colors.orange,
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.send),
            color: colorScheme.primary,
            onPressed: onSend,
            tooltip: 'Envoyer un message',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.red,
            onPressed: onDelete,
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }
}
