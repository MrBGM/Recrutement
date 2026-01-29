import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../providers/chat_provider.dart';

/// Écran de chat de groupe complet
class GroupChatScreen extends StatefulWidget {
  final Group group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final UserService _userService = UserService();
  late Group _group;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _refreshGroup();
  }

  Future<void> _refreshGroup() async {
    final updated = await _firestoreService.getGroupById(_group.id);
    if (updated != null && mounted) {
      setState(() => _group = updated);
    }
  }

  bool get _isAdmin {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return currentUserId != null && _group.adminIds.contains(currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Non connecté')));
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Créer un utilisateur fictif pour le ChatProvider (pour la compatibilité)
    final dummyUser = AppUser(
      id: _group.id,
      email: '',
      displayName: _group.name,
      isOnline: true,
    );

    return ChangeNotifierProvider(
      create: (_) => ChatProvider(
        currentUserId: currentUser.uid,
        currentUserName: currentUser.displayName ?? 'Utilisateur',
        otherUser: dummyUser,
        isGroupChat: true,
        groupId: _group.id,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: InkWell(
            onTap: () => _showGroupInfo(),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: _group.photoUrl != null
                      ? NetworkImage(_group.photoUrl!)
                      : null,
                  child: _group.photoUrl == null
                      ? Text(
                          _group.name.isNotEmpty
                              ? _group.name[0].toUpperCase()
                              : 'G',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _group.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_group.memberIds.length} membres',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withAlpha(179),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'info',
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Infos du groupe'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_isAdmin) ...[
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Modifier le groupe'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add_members',
                    child: ListTile(
                      leading: Icon(Icons.person_add),
                      title: Text('Ajouter des membres'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'leave',
                  child: ListTile(
                    leading: Icon(Icons.exit_to_app, color: Colors.red),
                    title: Text('Quitter le groupe',
                        style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Zone des messages
            Expanded(
              child: _buildMessagesList(currentUser.uid),
            ),
            // Zone de saisie
            Consumer<ChatProvider>(
              builder: (context, provider, _) => ChatInput(
                controller: provider.messageController,
                onSend: provider.sendMessage,
                onAITap: provider.handleAIButton,
                isAILoading: provider.isAILoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(String currentUserId) {
    return StreamBuilder<List<Message>>(
      stream: _getGroupMessagesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun message',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Soyez le premier à écrire !',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            final isMe = message.senderId == currentUserId;

            return MessageBubble(
              message: message,
              isMe: isMe,
              showSenderName: !isMe, // Afficher le nom dans les groupes
              onReact: (emoji) => _addReaction(message.id, emoji),
              onEdit: isMe ? () => _editMessage(message) : null,
              onDelete: () => _deleteMessage(message, isMe),
            );
          },
        );
      },
    );
  }

  Stream<List<Message>> _getGroupMessagesStream() {
    return _firestoreService
        .getMessagesStream(_group.id, FirebaseAuth.instance.currentUser!.uid);
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'info':
        _showGroupInfo();
        break;
      case 'edit':
        _showEditGroupDialog();
        break;
      case 'add_members':
        _showAddMembersDialog();
        break;
      case 'leave':
        _showLeaveGroupDialog();
        break;
    }
  }

  /// Affiche les informations du groupe
  void _showGroupInfo() {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: _group.photoUrl != null
                        ? NetworkImage(_group.photoUrl!)
                        : null,
                    child: _group.photoUrl == null
                        ? Text(
                            _group.name.isNotEmpty
                                ? _group.name[0].toUpperCase()
                                : 'G',
                            style: TextStyle(
                              fontSize: 32,
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _group.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_group.description != null &&
                      _group.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _group.description!,
                        style: TextStyle(color: colorScheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${_group.memberIds.length} membres',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Liste des membres
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Membres',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _group.memberIds.length,
                itemBuilder: (context, index) {
                  final memberId = _group.memberIds[index];
                  final isAdmin = _group.adminIds.contains(memberId);
                  final isCurrentUser = memberId == currentUserId;

                  return FutureBuilder<AppUser?>(
                    future: _userService.getUserById(memberId),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      final name = user?.displayName ?? 'Utilisateur';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(isCurrentUser ? 'Vous' : name),
                            if (isAdmin)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          user?.isOnline == true ? 'En ligne' : 'Hors ligne',
                          style: TextStyle(
                            color: user?.isOnline == true
                                ? Colors.green
                                : colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                        trailing: _isAdmin && !isCurrentUser
                            ? PopupMenuButton<String>(
                                onSelected: (action) =>
                                    _handleMemberAction(action, memberId),
                                itemBuilder: (context) => [
                                  if (!isAdmin)
                                    const PopupMenuItem(
                                      value: 'promote',
                                      child: Text('Nommer admin'),
                                    ),
                                  if (isAdmin)
                                    const PopupMenuItem(
                                      value: 'demote',
                                      child: Text('Retirer admin'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Exclure',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gère les actions sur un membre
  Future<void> _handleMemberAction(String action, String memberId) async {
    switch (action) {
      case 'promote':
        await _firestoreService.promoteToAdmin(
          groupId: _group.id,
          userId: memberId,
        );
        break;
      case 'demote':
        await _firestoreService.demoteFromAdmin(
          groupId: _group.id,
          userId: memberId,
        );
        break;
      case 'remove':
        await _firestoreService.removeGroupMember(
          groupId: _group.id,
          userId: memberId,
        );
        break;
    }
    _refreshGroup();
    if (mounted) Navigator.pop(context); // Ferme le bottom sheet
  }

  /// Affiche le dialog d'édition du groupe
  void _showEditGroupDialog() {
    final nameController = TextEditingController(text: _group.name);
    final descriptionController =
        TextEditingController(text: _group.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le groupe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du groupe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await _firestoreService.updateGroupInfo(
                  groupId: _group.id,
                  name: name,
                  description: descriptionController.text.trim(),
                );
                _refreshGroup();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  /// Affiche le dialog d'ajout de membres
  void _showAddMembersDialog() {
    final selectedIds = <String>{};
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter des membres'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: StreamBuilder<List<AppUser>>(
              stream: _userService.getAllUsers(currentUserId ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data ?? [];
                // Filtrer les utilisateurs déjà membres
                final availableUsers = users
                    .where((u) => !_group.memberIds.contains(u.id))
                    .toList();

                if (availableUsers.isEmpty) {
                  return const Center(
                    child: Text('Aucun contact disponible à ajouter'),
                  );
                }

                return ListView.builder(
                  itemCount: availableUsers.length,
                  itemBuilder: (context, index) {
                    final user = availableUsers[index];
                    final isSelected = selectedIds.contains(user.id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedIds.add(user.id);
                          } else {
                            selectedIds.remove(user.id);
                          }
                        });
                      },
                      title: Text(user.displayName),
                      subtitle: Text(
                        user.isOnline ? 'En ligne' : 'Hors ligne',
                        style: TextStyle(
                          color: user.isOnline ? Colors.green : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      secondary: CircleAvatar(
                        child: Text(user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: selectedIds.isEmpty
                  ? null
                  : () async {
                      for (final userId in selectedIds) {
                        await _firestoreService.addGroupMember(
                          groupId: _group.id,
                          userId: userId,
                        );
                      }
                      _refreshGroup();
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('${selectedIds.length} membre(s) ajouté(s)'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              child: Text('Ajouter (${selectedIds.length})'),
            ),
          ],
        ),
      ),
    );
  }

  /// Affiche le dialog pour quitter le groupe
  void _showLeaveGroupDialog() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOnlyAdmin =
        _isAdmin && _group.adminIds.length == 1 && _group.memberIds.length > 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: Text(
          isOnlyAdmin
              ? 'Vous êtes le seul admin. Veuillez nommer un autre admin avant de quitter ou supprimer le groupe.'
              : 'Voulez-vous vraiment quitter "${_group.name}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          if (!isOnlyAdmin)
            FilledButton(
              onPressed: () async {
                if (currentUserId != null) {
                  await _firestoreService.removeGroupMember(
                    groupId: _group.id,
                    userId: currentUserId,
                  );
                  if (mounted) {
                    Navigator.pop(context); // Dialog
                    Navigator.pop(context); // Screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vous avez quitté le groupe'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Quitter'),
            ),
        ],
      ),
    );
  }

  /// Ajoute une réaction à un message
  Future<void> _addReaction(String messageId, String emoji) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    await _firestoreService.addReaction(
      conversationId: _group.id,
      messageId: messageId,
      userId: currentUserId,
      emoji: emoji,
    );
  }

  /// Édite un message
  void _editMessage(Message message) {
    final controller = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                await _firestoreService.editMessage(
                  conversationId: _group.id,
                  messageId: message.id,
                  newContent: newContent,
                );
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  /// Supprime un message
  void _deleteMessage(Message message, bool isMe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Comment voulez-vous supprimer ce message ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          if (isMe)
            TextButton(
              onPressed: () async {
                await _firestoreService.deleteMessageForEveryone(
                  conversationId: _group.id,
                  messageId: message.id,
                );
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Supprimer pour tous',
                  style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () async {
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              if (currentUserId != null) {
                await _firestoreService.deleteMessageForMe(
                  conversationId: _group.id,
                  messageId: message.id,
                  userId: currentUserId,
                );
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Supprimer pour moi'),
          ),
        ],
      ),
    );
  }
}
