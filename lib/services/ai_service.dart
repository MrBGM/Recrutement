import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../config/api_config.dart';
import '../config/api_keys.dart';

/// Service d'intelligence artificielle
/// Gere les appels au backend pour la generation de suggestions
class AIService {
  // Cache pour eviter les appels repetes
  static final Map<String, _CachedAnalysis> _analysisCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Genere une suggestion de message
  Future<String> generateSuggestion({
    required String currentInput,
    required List<Message> recentMessages,
    required String currentUserId,
    required String currentUserName,
  }) async {
    try {
      // Essayer d'abord le backend
      final result = await _callBackend(
        currentInput: currentInput,
        recentMessages: recentMessages,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      );
      return result;
    } catch (e) {
      _debugLog('❌ Erreur backend: $e');

      // En cas d'erreur, utiliser le fallback si configure
      if (ApiConfig.enableFallback && ApiKeys.isGroqConfigured) {
        _debugLog('🔄 Utilisation du fallback Groq direct');
        return _callGroqDirectly(
          currentInput: currentInput,
          recentMessages: recentMessages,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
        );
      }

      // Si pas de fallback, renvoyer une erreur claire
      throw Exception(
          'Backend indisponible. Vérifiez que le serveur tourne sur ${ApiConfig.backendUrl}');
    }
  }

  /// Appelle le backend pour generer une suggestion
  Future<String> _callBackend({
    required String currentInput,
    required List<Message> recentMessages,
    required String currentUserId,
    required String currentUserName,
  }) async {
    final url = ApiConfig.suggestUrl;
    _debugLog('🌐 Appel backend: $url');

    final body = jsonEncode({
      'currentInput': currentInput,
      'messages': recentMessages
          .map((m) => {
                'content': m.content,
                'senderId': m.senderId,
                'senderName': m.senderName,
              })
          .toList(),
      'currentUserId': currentUserId,
      'currentUserName': currentUserName,
    });

    _debugLog('📦 Messages envoyés: ${recentMessages.length}');

    try {
      final response = await http
          .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      )
          .timeout(
        Duration(seconds: ApiConfig.receiveTimeout),
        onTimeout: () {
          throw Exception(
              'Timeout: Le serveur ne répond pas (>${ApiConfig.receiveTimeout}s)');
        },
      );

      _debugLog('📡 Status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final suggestion = data['data']['suggestion']?.trim() ?? '';
          _debugLog(
              '✅ Suggestion reçue: ${suggestion.substring(0, suggestion.length > 50 ? 50 : suggestion.length)}...');
          return suggestion;
        }
        throw Exception('Réponse invalide du serveur');
      } else {
        final error = jsonDecode(response.body);
        final errorMsg =
            error['error']?['message'] ?? 'Erreur API: ${response.statusCode}';
        _debugLog('❌ Erreur API: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      _debugLog('❌ Exception: $e');
      rethrow;
    }
  }

  /// Appel direct a l'API Groq (fallback)
  Future<String> _callGroqDirectly({
    required String currentInput,
    required List<Message> recentMessages,
    required String currentUserId,
    required String currentUserName,
  }) async {
    const baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
    final mode = currentInput.isEmpty ? 'suggest' : 'improve';

    _debugLog('🤖 Appel Groq direct - Mode: $mode');

    // Analyser la conversation
    final analysis = _analyzeConversation(
      recentMessages,
      currentUserId,
      currentUserName,
    );

    // Construire les prompts
    final systemPrompt = _buildSystemPrompt(mode, currentUserName, analysis);
    final userPrompt = _buildUserPrompt(
      mode,
      currentInput,
      recentMessages,
      currentUserId,
      currentUserName,
      analysis,
    );

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiKeys.groqApiKey}',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'max_tokens': 200,
          'temperature': 0.75,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestion =
            data['choices'][0]['message']['content']?.trim() ?? '';
        _debugLog('✅ Groq: Suggestion générée');
        return suggestion;
      } else {
        throw Exception('Erreur API Groq: ${response.statusCode}');
      }
    } catch (e) {
      _debugLog('❌ Erreur Groq: $e');
      rethrow;
    }
  }

  /// Verifie si le backend est disponible
  Future<bool> isBackendAvailable() async {
    try {
      _debugLog('🔍 Test de disponibilité backend...');
      final response = await http
          .get(Uri.parse(ApiConfig.statusUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final available = data['data']?['available'] == true;
        _debugLog(
            available ? '✅ Backend disponible' : '❌ Backend indisponible');
        return available;
      }
      _debugLog('❌ Backend status code: ${response.statusCode}');
      return false;
    } catch (e) {
      _debugLog('❌ Backend non accessible: $e');
      return false;
    }
  }

  /// Log de debug
  void _debugLog(String message) {
    if (ApiConfig.debugMode) {
      print('[AIService] $message');
    }
  }

  /// Analyse une conversation
  _ConversationAnalysis _analyzeConversation(
    List<Message> messages,
    String currentUserId,
    String currentUserName,
  ) {
    // Verifier le cache
    final cacheKey = '${currentUserId}_${messages.length}';
    final cached = _analysisCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _cacheDuration) {
      return cached.analysis;
    }

    if (messages.isEmpty) {
      return _ConversationAnalysis(
        tone: 'neutre',
        relationship: 'inconnu',
        topics: ['discussion generale'],
        conversationSummary: 'Nouvelle conversation',
        messageCount: 0,
        lastSpeaker: '',
        conversationFlow: 'debut',
        emotionalTone: 'neutre',
      );
    }

    final tone = _detectTone(messages);
    final relationship = _detectRelationship(messages, tone);
    final topics = _extractTopics(messages);
    final emotionalTone = _detectEmotionalTone(messages);
    final conversationFlow = _analyzeConversationFlow(messages, currentUserId);
    final summary = _createConversationSummary(messages, currentUserId, topics);

    final lastMessage = messages.last;
    final lastSpeaker =
        lastMessage.senderId == currentUserId ? 'moi' : lastMessage.senderName;

    final analysis = _ConversationAnalysis(
      tone: tone,
      relationship: relationship,
      topics: topics,
      conversationSummary: summary,
      messageCount: messages.length,
      lastSpeaker: lastSpeaker,
      conversationFlow: conversationFlow,
      emotionalTone: emotionalTone,
    );

    // Mettre en cache
    _analysisCache[cacheKey] = _CachedAnalysis(analysis, DateTime.now());

    return analysis;
  }

  String _detectTone(List<Message> messages) {
    int formalScore = 0;
    int informalScore = 0;

    const formalWords = [
      'bonjour',
      'bonsoir',
      'merci',
      'cordialement',
      'pourriez',
      'veuillez',
      'sincèrement'
    ];
    const informalWords = [
      'salut',
      'coucou',
      'ouais',
      'cool',
      'lol',
      'mdr',
      'ptdr',
      'tkt',
      'yo',
      'hey'
    ];

    for (final msg in messages) {
      final content = msg.content.toLowerCase();
      for (final word in formalWords) {
        if (content.contains(word)) formalScore++;
      }
      for (final word in informalWords) {
        if (content.contains(word)) informalScore++;
      }
    }

    if (formalScore > informalScore * 2) return 'formel';
    if (informalScore > formalScore) return 'informel';
    return 'neutre';
  }

  String _detectRelationship(List<Message> messages, String tone) {
    if (tone == 'formel') return 'professionnel';

    final content = messages.map((m) => m.content.toLowerCase()).join(' ');

    if (RegExp(r'\b(travail|projet|réunion|bureau|chef)\b').hasMatch(content)) {
      return 'collegue';
    }
    if (RegExp(r'\b(maman|papa|famille|parents?|frère|soeur)\b')
        .hasMatch(content)) {
      return 'famille';
    }
    if (RegExp(r'\b(chéri|bébé|mon amour|ma puce)\b').hasMatch(content)) {
      return 'couple';
    }

    return 'ami';
  }

  List<String> _extractTopics(List<Message> messages) {
    final topics = <String>[];
    final content = messages.map((m) => m.content.toLowerCase()).join(' ');

    final topicKeywords = {
      'travail': [
        'travail',
        'projet',
        'réunion',
        'bureau',
        'meeting',
        'boulot'
      ],
      'rendez-vous': [
        'rdv',
        'rendez-vous',
        'voir',
        'rencontrer',
        'heure',
        'demain'
      ],
      'loisirs': ['film', 'série', 'jeu', 'sport', 'musique', 'concert'],
      'nourriture': ['manger', 'restaurant', 'bouffe', 'dîner', 'déjeuner'],
      'voyage': ['voyage', 'vacances', 'partir', 'destination', 'avion'],
    };

    topicKeywords.forEach((topic, keywords) {
      if (keywords.any((keyword) => content.contains(keyword))) {
        topics.add(topic);
      }
    });

    return topics.isEmpty ? ['discussion generale'] : topics;
  }

  String _detectEmotionalTone(List<Message> messages) {
    int positiveScore = 0;
    int negativeScore = 0;

    final allContent = messages.map((m) => m.content).join(' ');
    final contentLower = allContent.toLowerCase();

    const positiveWords = [
      'content',
      'super',
      'génial',
      'cool',
      'parfait',
      'merci',
      'top',
      'excellent'
    ];
    const negativeWords = [
      'désolé',
      'dommage',
      'problème',
      'malheureusement',
      'triste',
      'difficile'
    ];
    const positiveEmojis = [
      '😊',
      '😂',
      '😄',
      '❤️',
      '👍',
      '🎉',
      '✨',
      '🥳',
      '😁'
    ];
    const negativeEmojis = ['😢', '😔', '😡', '💔', '😤', '😞', '😭'];

    for (final word in positiveWords) {
      if (contentLower.contains(word)) positiveScore++;
    }
    for (final word in negativeWords) {
      if (contentLower.contains(word)) negativeScore++;
    }
    for (final emoji in positiveEmojis) {
      if (allContent.contains(emoji)) positiveScore += 2;
    }
    for (final emoji in negativeEmojis) {
      if (allContent.contains(emoji)) negativeScore += 2;
    }

    if (positiveScore > negativeScore * 1.5) return 'positif';
    if (negativeScore > positiveScore) return 'negatif';
    return 'neutre';
  }

  String _analyzeConversationFlow(
      List<Message> messages, String currentUserId) {
    if (messages.length < 2) return 'debut';

    final recentMessages =
        messages.length > 5 ? messages.sublist(messages.length - 5) : messages;
    int questionCount = 0;
    int myMessages = 0;

    for (final msg in recentMessages) {
      if (msg.content.contains('?')) questionCount++;
      if (msg.senderId == currentUserId) myMessages++;
    }

    if (questionCount >= 2) return 'interrogatif';
    if (myMessages >= 3) return 'actif';
    return 'fluide';
  }

  String _createConversationSummary(
      List<Message> messages, String currentUserId, List<String> topics) {
    if (messages.isEmpty) return 'Nouvelle conversation';

    final otherMessages =
        messages.where((m) => m.senderId != currentUserId).toList();
    String summary = '';

    if (messages.length <= 3) {
      summary = 'Debut de conversation';
    } else if (messages.length <= 10) {
      summary = 'Conversation en cours';
    } else {
      summary = 'Discussion active';
    }

    if (topics.isNotEmpty && topics[0] != 'discussion generale') {
      summary += ' portant sur ${topics.take(2).join(", ")}';
    }

    if (otherMessages.isNotEmpty) {
      final lastOther = otherMessages.last.content;
      if (lastOther.contains('?')) {
        summary += '. Question en attente de reponse';
      }
    }

    return summary;
  }

  String _buildSystemPrompt(
      String mode, String userName, _ConversationAnalysis analysis) {
    final base =
        '''Tu es un assistant IA conversationnel expert qui aide $userName a communiquer efficacement.

CONTEXTE DE LA CONVERSATION:
- Ton general: ${analysis.tone}
- Type de relation: ${analysis.relationship}
- Sujets abordes: ${analysis.topics.join(', ')}
- Resume: ${analysis.conversationSummary}
- Ton emotionnel: ${analysis.emotionalTone}
- Flux: ${analysis.conversationFlow}''';

    if (mode == 'suggest') {
      return '''$base

MISSION - SUGGESTION DE REPONSE:
Tu dois proposer une reponse que $userName peut envoyer directement.

REGLES ABSOLUES:
- Reponds UNIQUEMENT avec le message suggere (aucune explication)
- Pas de guillemets, pas de preambule
- 1-3 phrases maximum
- Langage naturel et humain
- En francais
- Ne dis JAMAIS "En tant qu'assistant..." ou similaire
- Adapte le ton: ${analysis.tone == 'informel' ? 'court et direct' : 'complet mais concis'}''';
    }

    return '''$base

MISSION - AMELIORATION DE MESSAGE:
Tu dois ameliorer le brouillon de $userName tout en preservant son intention.

REGLES ABSOLUES:
- Reponds UNIQUEMENT avec le message ameliore (aucune explication)
- Pas de guillemets, pas de commentaires
- Garde la longueur similaire a l'original
- Corrige les fautes sans changer le sens
- En francais''';
  }

  String _buildUserPrompt(
    String mode,
    String currentInput,
    List<Message> messages,
    String currentUserId,
    String currentUserName,
    _ConversationAnalysis analysis,
  ) {
    final contextMessages =
        _buildStructuredContext(messages, currentUserId, currentUserName);

    if (mode == 'suggest') {
      final otherMessages =
          messages.where((m) => m.senderId != currentUserId).toList();

      if (otherMessages.isEmpty) {
        return '''HISTORIQUE:
$contextMessages

MISSION:
Propose un message pour que $currentUserName ${messages.isEmpty ? 'demarre' : 'relance'} cette conversation.''';
      }

      final lastOther = otherMessages.last;

      return '''HISTORIQUE:
$contextMessages

---

DERNIER MESSAGE:
${lastOther.senderName}: "${lastOther.content}"

MISSION:
Genere UNE reponse parfaite que $currentUserName peut envoyer a ${lastOther.senderName}.''';
    }

    return '''CONTEXTE:
$contextMessages

---

BROUILLON DE $currentUserName:
"$currentInput"

MISSION:
Ameliore ce brouillon en gardant le meme sens.''';
  }

  String _buildStructuredContext(
      List<Message> messages, String currentUserId, String currentUserName) {
    if (messages.isEmpty) return '[Nouvelle conversation]';

    final lines = <String>[];

    if (messages.length > 8) {
      final recentMessages = messages.sublist(messages.length - 6);
      lines.add('[${messages.length - 6} messages precedents...]');
      lines.add('');

      for (var i = 0; i < recentMessages.length; i++) {
        final msg = recentMessages[i];
        final isMe = msg.senderId == currentUserId;
        final prefix = isMe ? '[MOI] $currentUserName' : msg.senderName;
        lines.add('${i + 1}. $prefix: "${msg.content}"');
      }
    } else {
      for (var i = 0; i < messages.length; i++) {
        final msg = messages[i];
        final isMe = msg.senderId == currentUserId;
        final prefix = isMe ? '[MOI] $currentUserName' : msg.senderName;
        lines.add('${i + 1}. $prefix: "${msg.content}"');
      }
    }

    return lines.join('\n');
  }
}

/// Classe pour stocker l'analyse de la conversation
class _ConversationAnalysis {
  final String tone;
  final String relationship;
  final List<String> topics;
  final String conversationSummary;
  final int messageCount;
  final String lastSpeaker;
  final String conversationFlow;
  final String emotionalTone;

  _ConversationAnalysis({
    required this.tone,
    required this.relationship,
    required this.topics,
    required this.conversationSummary,
    required this.messageCount,
    required this.lastSpeaker,
    required this.conversationFlow,
    required this.emotionalTone,
  });
}

/// Classe pour le cache d'analyse
class _CachedAnalysis {
  final _ConversationAnalysis analysis;
  final DateTime timestamp;

  _CachedAnalysis(this.analysis, this.timestamp);
}
