# AI Chat - Application de Messagerie avec Intelligence Artificielle

Application de chat temps reel avec assistance IA integree. L'IA analyse le contexte de vos conversations et vous aide a formuler des reponses pertinentes et naturelles.

## Architecture du Projet

```
Test_Recrutement/
|
|-- backend/                    # API Backend Node.js
|   |-- src/
|   |   |-- ai/                 # Services IA (coeur du systeme)
|   |   |   |-- ai-service.js           # Service principal
|   |   |   |-- conversation-analyzer.js # Analyse contextuelle
|   |   |   |-- prompt-builder.js       # Construction des prompts
|   |   |-- config/             # Configuration
|   |   |-- middleware/         # Middlewares Express
|   |   |-- routes/             # Routes API
|   |   |-- utils/              # Utilitaires (logging)
|   |   |-- index.js            # Point d'entree serveur
|   |-- package.json
|   |-- .env.example
|
|-- lib/                        # Application Flutter
|   |-- config/                 # Configuration API
|   |   |-- api_config.dart
|   |-- models/                 # Modeles de donnees
|   |   |-- app_user.dart
|   |   |-- message.dart
|   |-- providers/              # State management
|   |   |-- chat_provider.dart
|   |-- screens/                # Ecrans de l'app
|   |   |-- login_screen.dart
|   |   |-- users_list_screen.dart
|   |   |-- chat_screen.dart
|   |-- services/               # Services (IA, Firestore, Auth)
|   |   |-- ai_service.dart
|   |   |-- firestore_service.dart
|   |   |-- auth_service.dart
|   |   |-- user_service.dart
|   |-- widgets/                # Widgets reutilisables
|   |   |-- chat_input.dart
|   |   |-- message_bubble.dart
|   |-- main.dart               # Point d'entree Flutter
|   |-- firebase_options.dart   # Config Firebase
|
|-- firebase.json               # Configuration Firebase
|-- firestore.rules             # Regles de securite
|-- pubspec.yaml                # Dependances Flutter
```

## Fonctionnalites

### Chat Temps Reel
- Messagerie instantanee via Firebase Firestore
- Indicateur de presence en ligne
- Liste de contacts avec statut
- Historique des conversations

### Assistant IA Intelligent
- **Mode Suggestion** : Genere une reponse basee sur le contexte (champ vide)
- **Mode Amelioration** : Reformule votre brouillon (champ rempli)
- Analyse contextuelle avancee :
  - Detection du ton (formel/informel)
  - Identification de la relation (ami, collegue, famille)
  - Extraction des sujets de conversation
  - Analyse du ton emotionnel + emojis

## Installation

### Prerequisites
- Node.js 18+
- Flutter 3.0+
- Firebase CLI + FlutterFire CLI
- Compte Groq (gratuit sur [console.groq.com](https://console.groq.com))

### 1. Configuration Firebase

```bash
# Installer les CLI
npm install -g firebase-tools
dart pub global activate flutterfire_cli

# Se connecter
firebase login

# Configurer le projet Flutter
flutterfire configure --project=ai-chat-23aa5
```

Cela genere automatiquement `lib/firebase_options.dart` avec les bonnes cles.

### 2. Backend Node.js

```bash
cd backend

# Installer les dependances
npm install

# Configurer l'environnement
cp .env.example .env
# Editer .env avec votre cle GROQ_API_KEY

# Demarrer le serveur
npm run dev
```

Le serveur demarre sur `http://localhost:3001`

### 3. Application Flutter

```bash
# A la racine du projet
flutter pub get

# Configurer l'URL du backend dans lib/config/api_config.dart
# Par defaut: http://localhost:3001

# Lancer l'application
flutter run -d chrome
```

## Configuration

### Backend (.env)

```env
GROQ_API_KEY=gsk_your_api_key_here
PORT=3001
NODE_ENV=development
AI_MODEL=llama-3.1-8b-instant
AI_MAX_TOKENS=200
AI_TEMPERATURE=0.75
```

### Frontend (lib/config/api_config.dart)

```dart
class ApiConfig {
  static const String backendUrl = 'http://localhost:3001';
  static const bool enableFallback = true;  // Appel direct Groq si backend down
}

class ApiKeys {
  static const String groqApiKey = 'gsk_...';  // Pour le mode fallback
}
```

## API Backend

| Methode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/api/ai/suggest` | Generer une suggestion |
| POST | `/api/ai/analyze` | Analyser une conversation |
| GET | `/api/ai/status` | Statut du service IA |
| GET | `/health` | Sante du serveur |

### Exemple

```bash
curl -X POST http://localhost:3001/api/ai/suggest \
  -H "Content-Type: application/json" \
  -d '{
    "currentInput": "",
    "messages": [{"content": "Salut!", "senderId": "u2", "senderName": "Alice"}],
    "currentUserId": "u1",
    "currentUserName": "Bob"
  }'
```

## Fonctionnement de l'IA

```
Clic sur bouton AI
        |
        v
   Champ vide ?
   /         \
  Oui        Non
   |          |
   v          v
SUGGEST    IMPROVE
   |          |
   +----+-----+
        |
        v
  Analyse contextuelle
  - Ton (formel/informel)
  - Relation (ami/collegue/famille)
  - Sujets detectes
  - Emotion + emojis
        |
        v
  Appel Backend/Groq
        |
        v
  Suggestion inseree
  (modifiable avant envoi)
```

## Technologies

| Composant | Technologies |
|-----------|-------------|
| **Backend** | Node.js, Express, Groq SDK, Winston |
| **Frontend** | Flutter 3.0+, Provider, Firebase |
| **Database** | Cloud Firestore |
| **Auth** | Firebase Authentication |
| **IA** | LLaMA 3.1 8B (via Groq API) |

## Licence

MIT License
