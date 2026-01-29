import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../config/api_config.dart';
import '../config/api_keys.dart';

/// Service d'intelligence artificielle AMÉLIORÉ
/// Utilise llama-3.1-70b-versatile pour des réponses plus naturelles
class AIService {
  // Cache pour éviter les appels répétés
  static final Map<String, _CachedAnalysis> _analysisCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  // ==========================================
  // CONFIGURATION DU MODÈLE
  // ==========================================

  /// Modèle principal (plus intelligent)
  static const String _primaryModel = 'llama-3.1-70b-versatile';

  /// Modèle fallback (plus rapide)
  static const String _fallbackModel = 'llama-3.1-8b-instant';

  /// Paramètres optimisés
  static const double _temperature = 0.7;
  static const double _topP = 0.9;
  static const double _presencePenalty = 0.1;
  static const int _maxTokens = 250;
  static const int _contextMessageLimit = 15; // 15-20 messages de contexte

  /// Génère une suggestion de message
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

      // En cas d'erreur, utiliser le fallback si configuré
      if (ApiConfig.enableFallback && ApiKeys.isGroqConfigured) {
        _debugLog('🔄 Utilisation du fallback Groq direct');
        return _callGroqDirectly(
          currentInput: currentInput,
          recentMessages: recentMessages,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
        );
      }

      throw Exception(
          'Backend indisponible. Vérifiez que le serveur tourne sur ${ApiConfig.backendUrl}');
    }
  }

  /// Appelle le backend pour générer une suggestion
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
                'timestamp': m.timestamp.toIso8601String(),
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

  /// Appel direct à l'API Groq (fallback) - VERSION AMÉLIORÉE
  Future<String> _callGroqDirectly({
    required String currentInput,
    required List<Message> recentMessages,
    required String currentUserId,
    required String currentUserName,
  }) async {
    const baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
    final mode = currentInput.isEmpty ? 'suggest' : 'improve';

    _debugLog('🤖 Appel Groq direct - Mode: $mode - Modèle: $_primaryModel');

    // Analyser la conversation de manière approfondie
    final analysis = _analyzeConversationEnhanced(
      recentMessages,
      currentUserId,
      currentUserName,
    );

    // Construire les prompts enrichis
    final systemPrompt =
        _buildEnhancedSystemPrompt(mode, currentUserName, analysis);
    final userPrompt = _buildEnhancedUserPrompt(
      mode,
      currentInput,
      recentMessages,
      currentUserId,
      currentUserName,
      analysis,
    );

    try {
      // Essayer d'abord avec le modèle principal (70B)
      final response = await _makeGroqRequest(
        baseUrl: baseUrl,
        model: _primaryModel,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      if (response != null) return response;

      // Fallback vers le modèle 8B si 70B échoue
      _debugLog('⚠️ Fallback vers $_fallbackModel');
      final fallbackResponse = await _makeGroqRequest(
        baseUrl: baseUrl,
        model: _fallbackModel,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      if (fallbackResponse != null) return fallbackResponse;

      throw Exception('Tous les modèles ont échoué');
    } catch (e) {
      _debugLog('❌ Erreur Groq: $e');
      rethrow;
    }
  }

  /// Fait une requête à l'API Groq
  Future<String?> _makeGroqRequest({
    required String baseUrl,
    required String model,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiKeys.groqApiKey}',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'max_tokens': _maxTokens,
          'temperature': _temperature,
          'top_p': _topP,
          'presence_penalty': _presencePenalty,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestion =
            data['choices'][0]['message']['content']?.trim() ?? '';
        _debugLog('✅ Groq ($model): Suggestion générée');
        return suggestion;
      } else {
        _debugLog('❌ Erreur Groq $model: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _debugLog('❌ Exception Groq $model: $e');
      return null;
    }
  }

  /// Vérifie si le backend est disponible
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

  // ==========================================
  // ANALYSE DE CONVERSATION AMÉLIORÉE
  // ==========================================

  /// Analyse une conversation de manière approfondie
  _EnhancedConversationAnalysis _analyzeConversationEnhanced(
    List<Message> messages,
    String currentUserId,
    String currentUserName,
  ) {
    // Vérifier le cache
    final cacheKey = '${currentUserId}_${messages.length}_enhanced';
    final cached = _analysisCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _cacheDuration) {
      return cached.analysis as _EnhancedConversationAnalysis;
    }

    if (messages.isEmpty) {
      return _EnhancedConversationAnalysis(
        tone: 'neutre',
        relationship: 'inconnu',
        topics: ['discussion generale'],
        conversationSummary: 'Nouvelle conversation',
        messageCount: 0,
        lastSpeaker: '',
        conversationFlow: 'debut',
        emotionalTone: 'neutre',
        // Nouveaux champs
        urgency: 'normal',
        pendingQuestions: 0,
        responseRhythm: 'normal',
        averageMessageLength: 0,
        timeOfDay: _getTimeOfDay(),
        detectedIntentions: ['discussion'],
        contactStyle: _ContactStyle.balanced,
      );
    }

    // Analyses existantes
    final tone = _detectTone(messages);
    final relationship = _detectRelationship(messages, tone);
    final topics = _extractTopics(messages);
    final emotionalTone = _detectEmotionalTone(messages);
    final conversationFlow = _analyzeConversationFlow(messages, currentUserId);
    final summary = _createConversationSummary(messages, currentUserId, topics);

    // Nouvelles analyses
    final urgency = _detectUrgency(messages);
    final pendingQuestions = _countPendingQuestions(messages, currentUserId);
    final responseRhythm = _analyzeResponseRhythm(messages);
    final averageLength = _calculateAverageMessageLength(messages);
    final timeOfDay = _getTimeOfDay();
    final intentions = _detectIntentions(messages);
    final contactStyle = _analyzeContactStyle(messages, currentUserId);

    final lastMessage = messages.last;
    final lastSpeaker =
        lastMessage.senderId == currentUserId ? 'moi' : lastMessage.senderName;

    final analysis = _EnhancedConversationAnalysis(
      tone: tone,
      relationship: relationship,
      topics: topics,
      conversationSummary: summary,
      messageCount: messages.length,
      lastSpeaker: lastSpeaker,
      conversationFlow: conversationFlow,
      emotionalTone: emotionalTone,
      urgency: urgency,
      pendingQuestions: pendingQuestions,
      responseRhythm: responseRhythm,
      averageMessageLength: averageLength,
      timeOfDay: timeOfDay,
      detectedIntentions: intentions,
      contactStyle: contactStyle,
    );

    // Mettre en cache
    _analysisCache[cacheKey] = _CachedAnalysis(analysis, DateTime.now());

    return analysis;
  }

  /// Détecte le niveau d'urgence
  String _detectUrgency(List<Message> messages) {
    if (messages.isEmpty) return 'normal';

    final recentContent = messages
        .take(5)
        .map((m) => m.content.toLowerCase())
        .join(' ');

    const urgentWords = [
      'urgent',
      'vite',
      'asap',
      'immédiatement',
      'maintenant',
      'sos',
      'help',
      'aide',
      'problème',
      'erreur',
      'bug',
      'bloqué',
      'deadline',
      '!!!',
      '???'
    ];

    int urgencyScore = 0;
    for (final word in urgentWords) {
      if (recentContent.contains(word)) urgencyScore++;
    }

    // Vérifier aussi les multiples points d'exclamation/interrogation
    urgencyScore += RegExp(r'[!?]{2,}').allMatches(recentContent).length;

    if (urgencyScore >= 3) return 'très urgent';
    if (urgencyScore >= 1) return 'urgent';
    return 'normal';
  }

  /// Compte les questions sans réponse
  int _countPendingQuestions(List<Message> messages, String currentUserId) {
    if (messages.isEmpty) return 0;

    int pendingCount = 0;
    bool lastWasQuestion = false;
    String? lastQuestionSender;

    for (final msg in messages.reversed) {
      final hasQuestion = msg.content.contains('?');

      if (hasQuestion && msg.senderId != currentUserId) {
        if (!lastWasQuestion || lastQuestionSender != currentUserId) {
          pendingCount++;
        }
        lastWasQuestion = true;
        lastQuestionSender = msg.senderId;
      } else if (msg.senderId == currentUserId) {
        // L'utilisateur a répondu, reset
        lastWasQuestion = false;
      }
    }

    return pendingCount;
  }

  /// Analyse le rythme de réponse
  String _analyzeResponseRhythm(List<Message> messages) {
    if (messages.length < 3) return 'normal';

    final timestamps =
        messages.map((m) => m.timestamp.millisecondsSinceEpoch).toList();
    final differences = <int>[];

    for (int i = 1; i < timestamps.length; i++) {
      differences.add(timestamps[i] - timestamps[i - 1]);
    }

    final avgDifference =
        differences.reduce((a, b) => a + b) / differences.length;
    final avgMinutes = avgDifference / (1000 * 60);

    if (avgMinutes < 2) return 'très rapide';
    if (avgMinutes < 10) return 'rapide';
    if (avgMinutes < 60) return 'normal';
    return 'lent';
  }

  /// Calcule la longueur moyenne des messages
  int _calculateAverageMessageLength(List<Message> messages) {
    if (messages.isEmpty) return 0;

    final totalLength =
        messages.map((m) => m.content.length).reduce((a, b) => a + b);
    return (totalLength / messages.length).round();
  }

  /// Obtient le moment de la journée
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 12) return 'matin';
    if (hour >= 12 && hour < 14) return 'midi';
    if (hour >= 14 && hour < 18) return 'après-midi';
    if (hour >= 18 && hour < 22) return 'soirée';
    return 'nuit';
  }

  /// Détecte les intentions dans les messages
  List<String> _detectIntentions(List<Message> messages) {
    final intentions = <String>[];
    final content = messages.map((m) => m.content.toLowerCase()).join(' ');

    final intentionPatterns = {
      'demande_aide': [
        'aide',
        'help',
        'comment',
        'pourrais-tu',
        'peux-tu',
        'stp',
        's\'il te plaît'
      ],
      'partage_info': [
        'regarde',
        'voici',
        'j\'ai trouvé',
        'fyi',
        'pour info',
        'btw'
      ],
      'humour': ['lol', 'mdr', 'ptdr', 'haha', 'xd', '😂', '🤣'],
      'invitation': [
        'on se voit',
        'tu viens',
        'rdv',
        'rendez-vous',
        'ce soir',
        'demain'
      ],
      'confirmation': ['ok', 'd\'accord', 'parfait', 'ça marche', 'validé'],
      'question': ['?', 'quoi', 'pourquoi', 'comment', 'quand', 'où'],
      'salutation': [
        'salut',
        'coucou',
        'bonjour',
        'hey',
        'hello',
        'bonsoir'
      ],
      'remerciement': ['merci', 'thanks', 'thx', 'cool', 'génial'],
    };

    intentionPatterns.forEach((intention, keywords) {
      if (keywords.any((keyword) => content.contains(keyword))) {
        intentions.add(intention);
      }
    });

    return intentions.isEmpty ? ['discussion'] : intentions;
  }

  /// Analyse le style de communication du contact
  _ContactStyle _analyzeContactStyle(
      List<Message> messages, String currentUserId) {
    final otherMessages =
        messages.where((m) => m.senderId != currentUserId).toList();

    if (otherMessages.isEmpty) return _ContactStyle.balanced;

    final avgLength = otherMessages.map((m) => m.content.length).reduce(
            (a, b) => a + b) /
        otherMessages.length;

    final hasEmojis = otherMessages.any((m) =>
        RegExp(r'[\u{1F600}-\u{1F64F}]', unicode: true).hasMatch(m.content));

    final hasSlang = otherMessages.any((m) {
      final content = m.content.toLowerCase();
      return content.contains('mdr') ||
          content.contains('lol') ||
          content.contains('tkt') ||
          content.contains('ptdr');
    });

    if (avgLength < 20 && (hasEmojis || hasSlang)) {
      return _ContactStyle.concise;
    } else if (avgLength > 100) {
      return _ContactStyle.verbose;
    }

    return _ContactStyle.balanced;
  }

  // ==========================================
  // DÉTECTION EXISTANTE (conservée)
  // ==========================================

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
      'sincèrement',
      'vous'
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
      'hey',
      'oklm',
      'bg',
      'wsh'
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

    if (RegExp(r'\b(travail|projet|réunion|bureau|chef|client)\b')
        .hasMatch(content)) {
      return 'collègue';
    }
    if (RegExp(r'\b(maman|papa|famille|parents?|frère|soeur)\b')
        .hasMatch(content)) {
      return 'famille';
    }
    if (RegExp(r'\b(chéri|bébé|mon amour|ma puce|je t\'aime)\b')
        .hasMatch(content)) {
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
        'boulot',
        'boss'
      ],
      'rendez-vous': [
        'rdv',
        'rendez-vous',
        'voir',
        'rencontrer',
        'heure',
        'demain',
        'ce soir'
      ],
      'loisirs': [
        'film',
        'série',
        'jeu',
        'sport',
        'musique',
        'concert',
        'netflix'
      ],
      'nourriture': [
        'manger',
        'restaurant',
        'bouffe',
        'dîner',
        'déjeuner',
        'faim'
      ],
      'voyage': ['voyage', 'vacances', 'partir', 'destination', 'avion', 'vol'],
      'tech': ['code', 'bug', 'app', 'site', 'ordi', 'phone'],
    };

    topicKeywords.forEach((topic, keywords) {
      if (keywords.any((keyword) => content.contains(keyword))) {
        topics.add(topic);
      }
    });

    return topics.isEmpty ? ['discussion générale'] : topics;
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
      'excellent',
      'nice',
      'trop bien'
    ];
    const negativeWords = [
      'désolé',
      'dommage',
      'problème',
      'malheureusement',
      'triste',
      'difficile',
      'nul',
      'merde'
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
      '😁',
      '🙌'
    ];
    const negativeEmojis = ['😢', '😔', '😡', '💔', '😤', '😞', '😭', '😩'];

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
    if (negativeScore > positiveScore) return 'négatif';
    return 'neutre';
  }

  String _analyzeConversationFlow(
      List<Message> messages, String currentUserId) {
    if (messages.length < 2) return 'début';

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
      summary = 'Début de conversation';
    } else if (messages.length <= 10) {
      summary = 'Conversation en cours';
    } else {
      summary = 'Discussion active';
    }

    if (topics.isNotEmpty && topics[0] != 'discussion générale') {
      summary += ' portant sur ${topics.take(2).join(", ")}';
    }

    if (otherMessages.isNotEmpty) {
      final lastOther = otherMessages.last.content;
      if (lastOther.contains('?')) {
        summary += '. Question en attente de réponse';
      }
    }

    return summary;
  }

  // ==========================================
  // PROMPTS ENRICHIS
  // ==========================================

  String _buildEnhancedSystemPrompt(
      String mode, String userName, _EnhancedConversationAnalysis analysis) {
    final styleGuidelines = _getStyleGuidelines(analysis);

    final base = '''Tu es un assistant IA conversationnel expert qui aide $userName à communiquer naturellement.

═══════════════════════════════════════
📊 ANALYSE APPROFONDIE DE LA CONVERSATION
═══════════════════════════════════════

CONTEXTE RELATIONNEL:
• Type de relation: ${analysis.relationship}
• Ton général: ${analysis.tone}
• Ambiance émotionnelle: ${analysis.emotionalTone}

DYNAMIQUE DE CONVERSATION:
• Flux actuel: ${analysis.conversationFlow}
• Rythme d'échange: ${analysis.responseRhythm}
• Questions en attente: ${analysis.pendingQuestions}
• Niveau d'urgence: ${analysis.urgency}

STYLE DU CONTACT:
• Longueur moyenne des messages: ${analysis.averageMessageLength} caractères
• Style détecté: ${analysis.contactStyle.name}

CONTEXTE TEMPOREL:
• Moment: ${analysis.timeOfDay}
• Sujets abordés: ${analysis.topics.join(', ')}

INTENTIONS DÉTECTÉES:
${analysis.detectedIntentions.map((i) => '• $i').join('\n')}

═══════════════════════════════════════
📝 RÉSUMÉ
═══════════════════════════════════════
${analysis.conversationSummary}
''';

    if (mode == 'suggest') {
      return '''$base

═══════════════════════════════════════
🎯 MISSION: SUGGESTION DE RÉPONSE
═══════════════════════════════════════

Tu dois proposer UNE réponse que $userName peut envoyer directement.

$styleGuidelines

RÈGLES ABSOLUES:
✓ Réponds UNIQUEMENT avec le message suggéré
✓ Pas de guillemets ni de préambule
✓ 1-3 phrases maximum (adapté au style du contact)
✓ Langage naturel et humain en français
✓ Ne JAMAIS dire "En tant qu'assistant..." ou similaire
✓ Ne JAMAIS commencer par "Je" si le ton est informel
✓ ${analysis.pendingQuestions > 0 ? 'PRIORITÉ: Répondre aux questions en attente' : 'Faire avancer la conversation'}
✓ ${analysis.urgency != 'normal' ? 'URGENT: Répondre de manière appropriée à l\'urgence' : ''}''';
    }

    return '''$base

═══════════════════════════════════════
🎯 MISSION: AMÉLIORATION DE MESSAGE
═══════════════════════════════════════

Tu dois améliorer le brouillon de $userName tout en préservant son intention.

$styleGuidelines

RÈGLES ABSOLUES:
✓ Réponds UNIQUEMENT avec le message amélioré
✓ Pas de guillemets ni de commentaires
✓ Garde une longueur similaire à l'original
✓ Corrige les fautes sans changer le sens
✓ Adapte le niveau de formalité au contexte
✓ En français''';
  }

  String _getStyleGuidelines(_EnhancedConversationAnalysis analysis) {
    final buffer = StringBuffer('ADAPTATION AU STYLE:\n');

    // Style basé sur la relation
    switch (analysis.relationship) {
      case 'ami':
        buffer.writeln('• Ton amical et décontracté');
        buffer.writeln('• Emojis occasionnels acceptés');
        break;
      case 'collègue':
        buffer.writeln('• Ton professionnel mais accessible');
        buffer.writeln('• Pas d\'emojis sauf 👍');
        break;
      case 'famille':
        buffer.writeln('• Ton chaleureux et affectueux');
        break;
      case 'couple':
        buffer.writeln('• Ton intime et attentionné');
        break;
      default:
        buffer.writeln('• Ton neutre et respectueux');
    }

    // Longueur adaptée au contact
    switch (analysis.contactStyle) {
      case _ContactStyle.concise:
        buffer.writeln('• Messages COURTS (< 20 mots)');
        buffer.writeln('• Style direct, pas de fioritures');
        break;
      case _ContactStyle.verbose:
        buffer.writeln('• Messages plus développés OK');
        buffer.writeln('• Explications détaillées bienvenues');
        break;
      default:
        buffer.writeln('• Longueur équilibrée (1-2 phrases)');
    }

    // Ton émotionnel
    if (analysis.emotionalTone == 'positif') {
      buffer.writeln('• Maintenir l\'énergie positive');
    } else if (analysis.emotionalTone == 'négatif') {
      buffer.writeln('• Ton empathique et compréhensif');
    }

    return buffer.toString();
  }

  String _buildEnhancedUserPrompt(
    String mode,
    String currentInput,
    List<Message> messages,
    String currentUserId,
    String currentUserName,
    _EnhancedConversationAnalysis analysis,
  ) {
    final contextMessages = _buildEnhancedContext(
        messages, currentUserId, currentUserName, analysis);

    if (mode == 'suggest') {
      final otherMessages =
          messages.where((m) => m.senderId != currentUserId).toList();

      if (otherMessages.isEmpty) {
        return '''═══════════════════════════════════════
📜 HISTORIQUE
═══════════════════════════════════════
$contextMessages

═══════════════════════════════════════
🎯 MISSION
═══════════════════════════════════════
Propose un message pour que $currentUserName ${messages.isEmpty ? 'démarre' : 'relance'} cette conversation.
${analysis.urgency != 'normal' ? '\n⚠️ Contexte urgent détecté - Adapter le ton' : ''}''';
      }

      final lastOther = otherMessages.last;

      return '''═══════════════════════════════════════
📜 HISTORIQUE (${messages.length} messages)
═══════════════════════════════════════
$contextMessages

═══════════════════════════════════════
💬 DERNIER MESSAGE DE ${lastOther.senderName.toUpperCase()}
═══════════════════════════════════════
"${lastOther.content}"

═══════════════════════════════════════
🎯 MISSION
═══════════════════════════════════════
Génère UNE réponse parfaite que $currentUserName peut envoyer à ${lastOther.senderName}.
${analysis.pendingQuestions > 0 ? '\n⚠️ ${analysis.pendingQuestions} question(s) attend(ent) une réponse!' : ''}''';
    }

    return '''═══════════════════════════════════════
📜 CONTEXTE
═══════════════════════════════════════
$contextMessages

═══════════════════════════════════════
✏️ BROUILLON DE ${currentUserName.toUpperCase()}
═══════════════════════════════════════
"$currentInput"

═══════════════════════════════════════
🎯 MISSION
═══════════════════════════════════════
Améliore ce brouillon en gardant le même sens et en l'adaptant au contexte.''';
  }

  String _buildEnhancedContext(
    List<Message> messages,
    String currentUserId,
    String currentUserName,
    _EnhancedConversationAnalysis analysis,
  ) {
    if (messages.isEmpty) return '[Nouvelle conversation]';

    final lines = <String>[];

    // Garder plus de messages (15-20)
    final messagesToShow =
        messages.length > _contextMessageLimit
            ? messages.sublist(messages.length - _contextMessageLimit)
            : messages;

    if (messages.length > _contextMessageLimit) {
      lines.add('[${messages.length - _contextMessageLimit} messages précédents omis...]');
      lines.add('');
    }

    for (var i = 0; i < messagesToShow.length; i++) {
      final msg = messagesToShow[i];
      final isMe = msg.senderId == currentUserId;
      final prefix = isMe ? '[MOI]' : '[${msg.senderName}]';

      // Ajouter l'heure pour le contexte temporel
      final time =
          '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

      lines.add('$time $prefix: "${msg.content}"');
    }

    return lines.join('\n');
  }
}

// ==========================================
// CLASSES DE SUPPORT
// ==========================================

/// Style de communication du contact
enum _ContactStyle {
  concise, // Messages courts, directs
  balanced, // Équilibré
  verbose, // Messages longs, détaillés
}

/// Analyse de conversation enrichie
class _EnhancedConversationAnalysis {
  final String tone;
  final String relationship;
  final List<String> topics;
  final String conversationSummary;
  final int messageCount;
  final String lastSpeaker;
  final String conversationFlow;
  final String emotionalTone;

  // Nouveaux champs
  final String urgency;
  final int pendingQuestions;
  final String responseRhythm;
  final int averageMessageLength;
  final String timeOfDay;
  final List<String> detectedIntentions;
  final _ContactStyle contactStyle;

  _EnhancedConversationAnalysis({
    required this.tone,
    required this.relationship,
    required this.topics,
    required this.conversationSummary,
    required this.messageCount,
    required this.lastSpeaker,
    required this.conversationFlow,
    required this.emotionalTone,
    required this.urgency,
    required this.pendingQuestions,
    required this.responseRhythm,
    required this.averageMessageLength,
    required this.timeOfDay,
    required this.detectedIntentions,
    required this.contactStyle,
  });
}

/// Classe pour le cache d'analyse
class _CachedAnalysis {
  final dynamic analysis;
  final DateTime timestamp;

  _CachedAnalysis(this.analysis, this.timestamp);
}
