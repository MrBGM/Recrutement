import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';

class ChatProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final AIService _aiService = AIService();
  final TextEditingController messageController = TextEditingController();

  final String _currentUserId;
  final String _currentUserName;
  final AppUser _otherUser;
  final String _conversationId;
  final bool _isGroupChat;
  final String? _groupId;
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isAILoading = false;
  String? _error;

  /// Crée un provider pour une conversation entre deux utilisateurs
  ChatProvider({
    required String currentUserId,
    required String currentUserName,
    required AppUser otherUser,
    bool isGroupChat = false,
    String? groupId,
  })  : _currentUserId = currentUserId,
        _currentUserName = currentUserName,
        _otherUser = otherUser,
        _isGroupChat = isGroupChat,
        _groupId = groupId,
        _conversationId = isGroupChat && groupId != null
            ? groupId
            : FirestoreService().getConversationId(currentUserId, otherUser.id);

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isAILoading => _isAILoading;
  String? get error => _error;
  String get currentUserId => _currentUserId;
  String get currentUserName => _currentUserName;
  AppUser get otherUser => _otherUser;
  String get conversationId => _conversationId;
  bool get isGroupChat => _isGroupChat;
  String? get groupId => _groupId;

  Stream<List<Message>> get messagesStream =>
      _firestoreService.getMessagesStream(_conversationId, _currentUserId, isGroup: _isGroupChat);

  Future<void> sendMessage() async {
    final content = messageController.text.trim();
    if (content.isEmpty) return;

    _error = null;
    messageController.clear();

    try {
      await _firestoreService.sendMessage(
        conversationId: _conversationId,
        content: content,
        senderId: _currentUserId,
        senderName: _currentUserName,
        isGroup: _isGroupChat,
        groupId: _groupId,
      );
      _updateMessageStatus(_conversationId, MessageStatus.delivered);
    } catch (e) {
      _error = 'Erreur lors de l\'envoi: $e';
      notifyListeners();
    }
  }

  Future<void> _updateMessageStatus(
    String conversationId,
    MessageStatus status,
  ) async {
    // Cette méthode serait appelée par un listener Firestore
    // quand le message est effectivement délivré
  }
  Future<void> markAsRead() async {
    try {
      await _firestoreService.markAllMessagesAsRead(
        _conversationId,
        _currentUserId,
      );
    } catch (e) {
      print('Erreur markAsRead: $e');
    }
  }

  /// Demande à l'IA d'aider à répondre dans la conversation
  Future<void> handleAIButton() async {
    _isAILoading = true;
    _error = null;
    notifyListeners();

    try {
      final recentMessages = await _firestoreService.getRecentMessages(
        conversationId: _conversationId,
        currentUserId: _currentUserId,
        limit: 10,
        isGroup: _isGroupChat,
      );

      final suggestion = await _aiService.generateSuggestion(
        currentInput: messageController.text.trim(),
        recentMessages: recentMessages,
        currentUserId: _currentUserId,
        currentUserName: _currentUserName,
      );

      // Insère la suggestion dans le champ
      messageController.text = suggestion;
    } catch (e) {
      _error = 'Erreur AI: $e';
    } finally {
      _isAILoading = false;
      notifyListeners();
    }
  }

  /// Supprime tous les messages de la conversation
  Future<void> clearChat() async {
    try {
      await _firestoreService.clearConversation(_conversationId, isGroup: _isGroupChat);
    } catch (e) {
      _error = 'Erreur lors de la suppression: $e';
      notifyListeners();
    }
  }

  Future<void> deleteMessageForMe(String messageId) async {
    try {
      await _firestoreService.deleteMessageForMe(
        conversationId: _conversationId,
        messageId: messageId,
        userId: _currentUserId,
        isGroup: _isGroupChat,
      );
    } catch (e) {
      _error = 'Erreur lors de la suppression: $e';
      notifyListeners();
    }
  }

  Future<void> deleteMessageForEveryone(String messageId) async {
    try {
      await _firestoreService.deleteMessageForEveryone(
        conversationId: _conversationId,
        messageId: messageId,
        isGroup: _isGroupChat,
      );
    } catch (e) {
      _error = 'Erreur lors de la suppression: $e';
      notifyListeners();
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    try {
      await _firestoreService.editMessage(
        conversationId: _conversationId,
        messageId: messageId,
        newContent: newContent,
        isGroup: _isGroupChat,
      );
    } catch (e) {
      _error = 'Erreur lors de l\'édition: $e';
      notifyListeners();
    }
  }

  Future<void> addReaction(String messageId, String emoji) async {
    try {
      await _firestoreService.addReaction(
        conversationId: _conversationId,
        messageId: messageId,
        userId: _currentUserId,
        emoji: emoji,
        isGroup: _isGroupChat,
      );
    } catch (e) {
      _error = 'Erreur lors de l\'ajout de réaction: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    markAsRead();
    messageController.dispose();
    super.dispose();
  }
}
