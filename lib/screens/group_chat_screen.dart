import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../models/group.dart';
import '../models/app_user.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';

/// Écran de conversation de groupe
class GroupChatScreen extends StatefulWidget {
  final Group group;
  final VoidCallback onBack;

  const GroupChatScreen({
    super.key,
    required this.group,
    required this.onBack,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final UserService _userService = UserService();

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _GroupInfoSheet(
          group: widget.group,
          scrollController: scrollController,
          userService: _userService,
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context, ChatProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider la discussion'),
        content: const Text('Voulez-vous supprimer tous les messages ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              provider.clearChat();
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context,
      ChatProvider provider, String messageId, bool forEveryone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            forEveryone ? 'Supprimer pour tous ?' : 'Supprimer pour vous ?'),
        content: Text(forEveryone
            ? 'Cette action est irréversible. Le message sera supprimé pour tous les membres du groupe.'
            : 'Le message ne sera plus visible pour vous.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (forEveryone) {
                provider.deleteMessageForEveryone(messageId);
              } else {
                provider.deleteMessageForMe(messageId);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(forEveryone
                      ? 'Message supprimé pour tous'
                      : 'Message supprimé pour vous'),
                  backgroundColor: forEveryone ? Colors.red : Colors.blue,
                ),
              );
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, ChatProvider provider,
      String messageId, String currentContent) {
    final controller = TextEditingController(text: currentContent);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Modifiez votre message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != currentContent) {
                provider.editMessage(messageId, newContent);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message modifié'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Non connecté')),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Créer un AppUser factice pour le groupe (pour compatibilité avec ChatProvider)
    final groupAsUser = AppUser(
      id: widget.group.id,
      displayName: widget.group.name,
      email: '',
      isOnline: false,
    );

    return ChangeNotifierProvider(
      key: ValueKey(widget.group.id),
      create: (_) => ChatProvider(
        currentUserId: currentUser.uid,
        currentUserName: currentUser.displayName ?? 'Utilisateur',
        otherUser: groupAsUser,
        isGroupChat: true,
        groupId: widget.group.id,
        groupName: widget.group.name,
      ),
      child: Builder(
        builder: (context) {
          final provider = context.watch<ChatProvider>();

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              title: InkWell(
                onTap: _showGroupInfo,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.groups,
                        size: 20,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.group.name,
                            style: const TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${widget.group.memberIds.length} membres',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                              color: colorScheme.onPrimaryContainer
                                  .withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Infos du groupe',
                  onPressed: _showGroupInfo,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Vider la discussion',
                  onPressed: () => _showClearDialog(context, provider),
                ),
              ],
            ),
            body: Column(
              children: [
                // Affichage des erreurs
                if (provider.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: colorScheme.errorContainer,
                    child: Text(
                      provider.error!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),

                // Liste des messages
                Expanded(
                  child: StreamBuilder<List<Message>>(
                    stream: provider.messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Erreur: ${snapshot.error}'),
                        );
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
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
                                'Aucun message',
                                style: TextStyle(
                                  color: colorScheme.outline,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Commencez la conversation !',
                                style: TextStyle(
                                  color: colorScheme.outline,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: false,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe =
                              message.senderId == provider.currentUserId;

                          return MessageBubble(
                            key: ValueKey(message.id),
                            message: message,
                            isMe: isMe,
                            onDeleteForMe: (messageId) =>
                                _showDeleteConfirmationDialog(
                                    context, provider, messageId, false),
                            onDeleteForEveryone: (messageId) =>
                                _showDeleteConfirmationDialog(
                                    context, provider, messageId, true),
                            onEdit: (messageId, newContent) => _showEditDialog(
                                context, provider, messageId, newContent),
                            onReaction: (messageId, emoji) =>
                                provider.addReaction(messageId, emoji),
                            onSwipeReply: () {},
                          );
                        },
                      );
                    },
                  ),
                ),

                // Zone de saisie
                const ChatInput(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Feuille d'informations du groupe
class _GroupInfoSheet extends StatelessWidget {
  final Group group;
  final ScrollController scrollController;
  final UserService userService;

  const _GroupInfoSheet({
    required this.group,
    required this.scrollController,
    required this.userService,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isAdmin = group.adminIds.contains(currentUserId);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        children: [
          // Poignée
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // En-tête du groupe
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.groups,
                    size: 48,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (group.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    group.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${group.memberIds.length} membres',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Liste des membres
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Membres',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),

          ...group.memberIds.map((memberId) {
            final isMemberAdmin = group.adminIds.contains(memberId);

            return FutureBuilder<AppUser?>(
              future: userService.getUserById(memberId),
              builder: (context, snapshot) {
                final user = snapshot.data;
                final displayName = user?.displayName ?? 'Utilisateur';
                final isOnline = user?.isOnline ?? false;

                return ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
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
                  title: Row(
                    children: [
                      Text(displayName),
                      if (memberId == currentUserId) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(vous)',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    isOnline ? 'En ligne' : 'Hors ligne',
                    style: TextStyle(
                      color: isOnline ? Colors.green : colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                  trailing: isMemberAdmin
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        )
                      : null,
                );
              },
            );
          }),

          const SizedBox(height: 24),

          // Actions
          if (isAdmin) ...[
            const Divider(),
            ListTile(
              leading: Icon(Icons.edit, color: colorScheme.primary),
              title: const Text('Modifier le groupe'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Ouvrir l'écran d'édition du groupe
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.green),
              title: const Text('Ajouter des membres'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Ouvrir l'écran d'ajout de membres
              },
            ),
          ],

          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text(
              'Quitter le groupe',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              // TODO: Implémenter quitter le groupe
              Navigator.pop(context);
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
