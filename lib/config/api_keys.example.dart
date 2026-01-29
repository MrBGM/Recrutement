/// Configuration des clés API
///
/// INSTRUCTIONS :
/// 1. Copiez ce fichier et renommez-le en 'api_keys.dart'
/// 2. Remplacez 'YOUR_GROQ_API_KEY_HERE' par votre vraie clé API Groq
/// 3. Ne commitez JAMAIS le fichier api_keys.dart (il est dans .gitignore)
///
/// Pour obtenir une clé API Groq :
/// - Allez sur https://console.groq.com/
/// - Créez un compte ou connectez-vous
/// - Générez une nouvelle clé API

class ApiKeys {
  // Clé API Groq pour les suggestions IA
  static const String groqApiKey = 'YOUR_GROQ_API_KEY_HERE';

  /// Vérifie si la clé Groq est configurée
  static bool get isGroqConfigured =>
      groqApiKey.isNotEmpty && !groqApiKey.contains('YOUR_');
}
