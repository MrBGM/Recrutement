import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';

/// Bulle de message complète (style WhatsApp)
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onSwipeReply;
  final Function(String messageId)? onDeleteForMe;
  final Function(String messageId)? onDeleteForEveryone;
  final Function(String messageId, String newContent)? onEdit;
  final Function(String messageId, String emoji)? onReaction;
  final VoidCallback? onImageTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onSwipeReply,
    this.onDeleteForMe,
    this.onDeleteForEveryone,
    this.onEdit,
    this.onReaction,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Message supprimé pour tous
    if (message.isDeletedForEveryone) {
      return _buildDeletedMessage(context);
    }

    return GestureDetector(
      onLongPress: () => _showMessageMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) _buildAvatar(context),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Message de réponse (si présent)
                  if (message.replyToMessageId != null)
                    _buildReplyPreview(context),

                  // Bulle principale
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Contenu du message
                        _buildMessageContent(context),

                        // Footer (timestamp + statut)
                        _buildMessageFooter(context),
                      ],
                    ),
                  ),

                  // Réactions
                  if (message.reactions.isNotEmpty) _buildReactions(context),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isMe) const SizedBox(width: 24), // Espace pour alignement
          ],
        ),
      ),
    );
  }

  /// Avatar de l'expéditeur
  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        message.senderName[0].toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  /// Aperçu du message de réponse
  Widget _buildReplyPreview(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 30,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.replyToSenderName ?? 'Utilisateur',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  message.replyToContent ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Contenu du message (texte, image, etc.)
  Widget _buildMessageContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = isMe ? colorScheme.onPrimary : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom de l'expéditeur (si pas moi)
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: colorScheme.primary,
                ),
              ),
            ),

          // Image (si type image)
          if (message.type == MessageType.image && message.mediaUrl != null)
            GestureDetector(
              onTap: onImageTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: message.mediaUrl!,
                  width: 200,
                  placeholder: (context, url) => Container(
                    width: 200,
                    height: 150,
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),

          // Texte du message
          if (message.content.isNotEmpty)
            Text(
              message.content,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
              ),
            ),
        ],
      ),
    );
  }

  /// Footer (timestamp + statut + édité)
  Widget _buildMessageFooter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final metaColor =
        (isMe ? colorScheme.onPrimary : colorScheme.onSurface).withOpacity(0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge "modifié"
          if (message.isEdited) ...[
            Icon(Icons.edit, size: 12, color: metaColor),
            const SizedBox(width: 4),
          ],

          // Timestamp
          Text(
            DateFormat('HH:mm').format(message.timestamp),
            style: TextStyle(fontSize: 11, color: metaColor),
          ),

          // Statut (seulement si c'est mon message)
          if (isMe) ...[
            const SizedBox(width: 4),
            _buildStatusIcon(metaColor),
          ],
        ],
      ),
    );
  }

  /// Icône de statut du message
  Widget _buildStatusIcon(Color color) {
    switch (message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color,
          ),
        );
      case MessageStatus.sent:
        return Icon(Icons.check, size: 16, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 16, color: color);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 16, color: Colors.blue);
      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 16, color: Colors.red);
    }
  }

  /// Réactions au message
  Widget _buildReactions(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: message.reactions.entries.take(3).map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(entry.value, style: const TextStyle(fontSize: 16)),
          );
        }).toList(),
      ),
    );
  }

  /// Message supprimé
  Widget _buildDeletedMessage(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              '🚫 Ce message a été supprimé',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Menu contextuel
  void _showMessageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.blue),
              title: const Text('Répondre'),
              onTap: () {
                Navigator.pop(context);
                onSwipeReply?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.blue),
              title: const Text('Copier'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.add_reaction_outlined, color: Colors.orange),
              title: const Text('Réagir'),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(context);
              },
            ),
            if (isMe && onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text('Modifier'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context);
                },
              ),
            if (onDeleteForMe != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.grey),
                title: const Text('Supprimer pour moi'),
                onTap: () {
                  Navigator.pop(context);
                  onDeleteForMe?.call(message.id);
                },
              ),
            if (isMe && onDeleteForEveryone != null)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Supprimer pour tous'),
                onTap: () {
                  Navigator.pop(context);
                  onDeleteForEveryone?.call(message.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Sélecteur de réaction rapide
  void _showReactionPicker(BuildContext context) {
    final reactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          children: reactions.map((emoji) {
            return GestureDetector(
              onTap: () {
                onReaction?.call(message.id, emoji);
                Navigator.pop(context);
              },
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Dialogue d'édition
  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Nouveau message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                onEdit?.call(message.id, newContent);
              }
              Navigator.pop(context);
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }
}
