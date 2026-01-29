/// Configuration de l'API backend
/// Ce fichier centralise toutes les configurations liees a l'API
library;

class ApiConfig {
  // URL du backend - A MODIFIER selon votre environnement
  // En developpement local:
  static const String backendUrl =
      'https://test-recrutement-backend.onrender.com';

  // En production (exemple avec Cloud Run):
  // static const String backendUrl = 'https://ai-chat-backend-xxxxx.run.app';

  // Endpoints de l'API
  static const String aiSuggestEndpoint = '/api/ai/suggest';
  static const String aiAnalyzeEndpoint = '/api/ai/analyze';
  static const String aiStatusEndpoint = '/api/ai/status';
  static const String healthEndpoint = '/health';

  // URLs completes
  static String get suggestUrl => '$backendUrl$aiSuggestEndpoint';
  static String get analyzeUrl => '$backendUrl$aiAnalyzeEndpoint';
  static String get statusUrl => '$backendUrl$aiStatusEndpoint';
  static String get healthUrl => '$backendUrl$healthEndpoint';

  // Configuration des timeouts (en secondes)
  static const int connectionTimeout = 15; // Augmenté pour Flutter web
  static const int receiveTimeout = 45; // Augmenté pour les réponses IA

  // Configuration du mode fallback (appel direct a Groq si backend indisponible)
  static const bool enableFallback = true;

  // Mode debug pour voir les requêtes HTTP
  static const bool debugMode = true;
}
