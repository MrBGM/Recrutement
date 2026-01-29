import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../models/app_user.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../services/user_service.dart';

/// Écran de conversation entre deux utilisateurs
class ChatScreen extends StatelessWidget {
  final VoidCallback onBack;

  const ChatScreen({super.key, required this.onBack});

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
            ? 'Cette action est irréversible. Le message sera supprimé pour tous les participants.'
            : 'Le message ne sera plus visible pour vous, mais restera visible pour ${provider.otherUser.displayName}.'),
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

  void _replyToMessage(
      BuildContext context, ChatProvider provider, Message message) {
    provider.messageController.text = "@${message.senderName} ";
    provider.messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: provider.messageController.text.length),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Réponse à ${message.senderName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final otherUser = provider.otherUser;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: _buildAppBarTitle(context, otherUser),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
        actions: [
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

          // ✨ NOUVEAU : Indicateur "en train d'écrire"
          _TypingIndicator(otherUserId: otherUser.id),

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
                          Icons.chat_bubble_outline,
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
                          'Dites bonjour à ${otherUser.displayName} !',
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
                    return MessageBubble(
                      key: ValueKey(message.id),
                      message: message,
                      isMe: message.senderId == provider.currentUserId,
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
                      onSwipeReply: () =>
                          _replyToMessage(context, provider, message),
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
  }

  Widget _buildAppBarTitle(BuildContext context, AppUser otherUser) {
    return Row(
      children: [
        // Avatar avec indicateur en ligne
        Stack(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                otherUser.displayName.isNotEmpty
                    ? otherUser.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: otherUser.isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Nom et statut
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                otherUser.displayName,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                otherUser.isOnline ? 'En ligne' : 'Hors ligne',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: otherUser.isOnline
                      ? Colors.green
                      : Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ✨ NOUVEAU : Indicateur "en train d'écrire..."
class _TypingIndicator extends StatelessWidget {
  final String otherUserId;

  const _TypingIndicator({required this.otherUserId});

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return StreamBuilder<AppUser?>(
      stream: userService.getUserById(otherUserId).asStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final user = snapshot.data!;
        final conversationId = context.read<ChatProvider>().conversationId;

        if (!user.isTypingIn(conversationId)) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[100],
          child: Row(
            children: [
              Text(
                '${user.displayName} est en train d\'écrire',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
