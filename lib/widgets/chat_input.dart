import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/chat_provider.dart';
import '../services/firestore_service.dart';

/// Zone de saisie avec bouton envoyer et bouton AI ✨
class ChatInput extends StatefulWidget {
  const ChatInput({super.key});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isTyping = false;

  void _handleTextChange(String text, ChatProvider provider) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Mettre à jour le statut "en train d'écrire"
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _firestoreService.setTypingStatus(
        conversationId: provider.conversationId,
        userId: currentUser.uid,
        isTyping: true,
      );
    } else if (text.isEmpty && _isTyping) {
      _isTyping = false;
      _firestoreService.setTypingStatus(
        conversationId: provider.conversationId,
        userId: currentUser.uid,
        isTyping: false,
      );
    }
  }

  void _handleSend(ChatProvider provider) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Arrêter le statut "en train d'écrire"
    if (_isTyping) {
      _isTyping = false;
      _firestoreService.setTypingStatus(
        conversationId: provider.conversationId,
        userId: currentUser.uid,
        isTyping: false,
      );
    }

    // Envoyer le message
    provider.sendMessage();
  }

  @override
  void dispose() {
    // S'assurer qu'on arrête le statut "en train d'écrire" quand on quitte
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && _isTyping) {
      // Note: Ceci peut ne pas fonctionner correctement si le provider n'est plus disponible
      _isTyping = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Bouton AI ✨
            _AIButton(
              isLoading: provider.isAILoading,
              onPressed: provider.handleAIButton,
            ),

            const SizedBox(width: 8),

            // Champ de saisie
            Expanded(
              child: TextField(
                controller: provider.messageController,
                onChanged: (text) => _handleTextChange(text, provider),
                decoration: InputDecoration(
                  hintText: 'Écrire un message...',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(provider),
              ),
            ),

            const SizedBox(width: 8),

            // Bouton envoyer
            IconButton(
              onPressed: () => _handleSend(provider),
              icon: Icon(
                Icons.send_rounded,
                color: colorScheme.primary,
              ),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton AI avec animation de chargement
class _AIButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _AIButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.tertiary,
                colorScheme.primary,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '✨',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
