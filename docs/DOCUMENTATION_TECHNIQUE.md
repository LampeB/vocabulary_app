# VocabApp - Documentation Technique

## Architecture Générale

### Stack Technologique

| Couche | Technologie | Version |
|--------|-------------|---------|
| Framework | Flutter | 3.x |
| Langage | Dart | 3.x |
| Base de données | SQLite | via sqflite/sqflite_common_ffi |
| TTS | ElevenLabs API | v1 |
| STT | speech_to_text | Natif Flutter |
| Audio | just_audio | - |
| Tests E2E | Appium Flutter Driver | - |

### Structure du Projet

```
vocabulary_app/
├── lib/
│   ├── main.dart                 # Point d'entrée principal
│   ├── main_appium.dart          # Point d'entrée pour tests E2E
│   ├── config/
│   │   ├── api_config.dart       # Configuration API
│   │   ├── app_config.dart       # Configuration déploiement
│   │   └── constants.dart        # Constantes applicatives
│   ├── models/
│   │   ├── vocabulary_list.dart  # Modèle liste
│   │   ├── concept.dart          # Modèle concept/mot
│   │   ├── word_variant.dart     # Modèle variante
│   │   ├── variant_progress.dart # Modèle progression
│   │   └── audio_settings.dart   # Modèle paramètres audio
│   ├── screens/
│   │   ├── home_screen.dart      # Écran d'accueil
│   │   ├── list_detail_screen.dart
│   │   ├── quiz_screen.dart      # Quiz mode texte
│   │   ├── quiz_screen_STT.dart  # Quiz mode vocal
│   │   └── settings_screen.dart
│   ├── services/
│   │   ├── database/
│   │   │   ├── database_service.dart
│   │   │   ├── vocabulary_list_repository.dart
│   │   │   └── concept_repository.dart
│   │   ├── audio/
│   │   │   ├── audio_service.dart        # Interface abstraite
│   │   │   ├── local_audio_service.dart  # Stockage local
│   │   │   ├── backend_audio_service.dart
│   │   │   ├── elevenlabs_service.dart   # API TTS
│   │   │   ├── audio_player_service.dart
│   │   │   └── audio_file_manager.dart
│   │   └── speech/
│   │       └── speech_recognition_service.dart
│   └── utils/
│       ├── answer_validator.dart  # Validation réponses
│       ├── srs_algorithm.dart     # Algorithme SRS
│       └── audio_preferences.dart
├── appium-tests/                  # Tests E2E
│   ├── features/                  # Scénarios Gherkin
│   ├── step-definitions/          # Implémentation steps
│   └── page-objects/              # Pattern Page Object
└── docs/                          # Documentation
```

---

## Modèles de Données

### Schéma de Base de Données

```sql
-- Table des listes de vocabulaire
CREATE TABLE vocabulary_lists (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    lang1_code TEXT NOT NULL DEFAULT 'fr',
    lang2_code TEXT NOT NULL DEFAULT 'ko',
    created_at TEXT NOT NULL,
    total_concepts INTEGER DEFAULT 0,
    is_downloaded INTEGER DEFAULT 0,
    download_status TEXT DEFAULT 'idle'
);

-- Table des concepts (mots)
CREATE TABLE concepts (
    id TEXT PRIMARY KEY,
    list_id TEXT NOT NULL,
    category TEXT,
    context_lang1 TEXT,
    context_lang2 TEXT,
    image_url TEXT,
    example_sentence_lang1 TEXT,
    example_sentence_lang2 TEXT,
    notes TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (list_id) REFERENCES vocabulary_lists(id) ON DELETE CASCADE
);

-- Table des variantes de mots
CREATE TABLE word_variants (
    id TEXT PRIMARY KEY,
    concept_id TEXT NOT NULL,
    word TEXT NOT NULL,
    lang_code TEXT NOT NULL,
    register_tag TEXT DEFAULT 'neutral',
    context_tags TEXT,  -- JSON array
    position INTEGER DEFAULT 0,
    is_primary INTEGER DEFAULT 1,
    audio_hash TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (concept_id) REFERENCES concepts(id) ON DELETE CASCADE
);

-- Table de progression SRS
CREATE TABLE variant_progress (
    id TEXT PRIMARY KEY,
    variant_id TEXT NOT NULL,
    direction TEXT NOT NULL,  -- 'lang1_to_lang2' ou 'lang2_to_lang1'
    times_shown_as_question INTEGER DEFAULT 0,
    times_shown_as_answer INTEGER DEFAULT 0,
    times_answered_correctly INTEGER DEFAULT 0,
    times_user_preferred INTEGER DEFAULT 0,
    last_seen_date TEXT,
    next_review_date TEXT,
    FOREIGN KEY (variant_id) REFERENCES word_variants(id) ON DELETE CASCADE
);
```

### Modèle VocabularyList

```dart
class VocabularyList {
  final String id;           // UUID v4
  final String name;
  final String lang1Code;    // Ex: 'fr'
  final String lang2Code;    // Ex: 'ko'
  final String createdAt;    // ISO8601
  final int totalConcepts;
  final bool isDownloaded;
  final String downloadStatus;

  // Sérialisation SQLite
  Map<String, dynamic> toMap();
  factory VocabularyList.fromMap(Map<String, dynamic> map);
}
```

### Modèle Concept

```dart
class Concept {
  final String id;
  final String listId;       // FK vers VocabularyList
  final String? category;
  final String? contextLang1;
  final String? contextLang2;
  final String? imageUrl;
  final String? exampleSentenceLang1;
  final String? exampleSentenceLang2;
  final String? notes;
  final String createdAt;
}
```

### Modèle WordVariant

```dart
class WordVariant {
  final String id;
  final String conceptId;    // FK vers Concept
  final String word;         // Le mot lui-même
  final String langCode;     // Code langue
  final String registerTag;  // formal, neutral, informal, very_informal
  final List<String> contextTags;
  final int position;
  final bool isPrimary;
  final String? audioHash;   // Hash MD5 pour identifier l'audio
  final String createdAt;
}
```

### Modèle VariantProgress

```dart
class VariantProgress {
  final String id;
  final String variantId;
  final String direction;
  final int timesShownAsQuestion;
  final int timesShownAsAnswer;
  final int timesAnsweredCorrectly;
  final int timesUserPreferred;
  final String? lastSeenDate;
  final String? nextReviewDate;

  // Propriétés calculées
  double get masteryLevel =>
      timesShownAsQuestion > 0
          ? timesAnsweredCorrectly / timesShownAsQuestion
          : 0.0;

  bool get isKnown => masteryLevel >= 0.7;
}
```

---

## Services

### DatabaseService (Singleton)

```dart
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  // Initialisation cross-platform
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Mobile: sqflite standard
    // Desktop: sqflite_common_ffi avec FFI
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // ...
  }
}
```

### AudioService (Interface)

```dart
abstract class AudioService {
  /// Génère ou récupère l'audio pour un texte
  Future<AudioResult> getOrGenerateAudio({
    required String text,
    required String langCode,
    bool forceRegenerate = false,
    void Function(double)? onProgress,
  });

  /// Récupère l'URL de lecture pour un hash
  Future<String?> getAudioUrl(String hash);

  /// Vérifie si l'audio existe en cache
  Future<bool> audioExists(String hash);

  /// Supprime un fichier audio
  Future<void> deleteAudio(String hash);

  /// Calcule le hash MD5 pour text+langue
  String calculateHash(String text, String langCode);
}

class AudioResult {
  final String hash;
  final String audioUrl;
  final bool fromCache;
}
```

### ElevenLabsService

```dart
class ElevenLabsService {
  static const String baseUrl = 'https://api.elevenlabs.io/v1';

  Future<Uint8List> generateSpeech({
    required String text,
    required String voiceId,
    double stability = 0.5,
    double similarityBoost = 0.75,
    String modelId = 'eleven_multilingual_v2',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/text-to-speech/$voiceId'),
      headers: {
        'xi-api-key': ApiConfig.elevenLabsApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'model_id': modelId,
        'voice_settings': {
          'stability': stability,
          'similarity_boost': similarityBoost,
        },
      }),
    );
    return response.bodyBytes;
  }
}
```

### SpeechRecognitionService

```dart
class SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();

  Future<bool> initialize() async {
    return await _speech.initialize(
      onError: (error) => _handleError(error),
      onStatus: (status) => _handleStatus(status),
    );
  }

  Future<void> startListening({
    required String langCode,
    required Function(String) onResult,
    Function(double)? onConfidence,
  }) async {
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
        onConfidence?.call(result.confidence);
      },
      localeId: _getLocaleId(langCode),
    );
  }

  String _getLocaleId(String langCode) {
    return {
      'fr': 'fr_FR',
      'ko': 'ko_KR',
      'en': 'en_US',
    }[langCode] ?? 'en_US';
  }
}
```

---

## Algorithmes

### Algorithme SRS

```dart
class SRSAlgorithm {
  static const List<int> intervals = [1, 3, 7, 14, 30, 90];
  static const double masteryThreshold = 0.7;

  /// Calcule la prochaine date de révision
  static DateTime calculateNextReview({
    required bool wasCorrect,
    required double masteryLevel,
    required int currentInterval,
  }) {
    if (!wasCorrect) {
      // Réponse incorrecte: réviser demain
      return DateTime.now().add(Duration(days: 1));
    }

    // Trouver l'intervalle suivant
    int nextInterval = intervals.firstWhere(
      (i) => i > currentInterval,
      orElse: () => intervals.last,
    );

    // Ajuster selon la maîtrise
    double adjustment = 0.5 + masteryLevel * 0.5;
    int adjustedDays = (nextInterval * adjustment).round();

    return DateTime.now().add(Duration(days: adjustedDays));
  }

  /// Calcule le score de priorité pour la sélection
  static double calculatePriority({
    required double masteryLevel,
    required DateTime? nextReviewDate,
  }) {
    double masteryScore = (1.0 - masteryLevel) * 10;

    double overdueScore = 0;
    if (nextReviewDate != null) {
      int daysOverdue = DateTime.now().difference(nextReviewDate).inDays;
      overdueScore = daysOverdue > 0 ? daysOverdue * 2.0 : 0;
    }

    return masteryScore + overdueScore;
  }

  /// Sélectionne les mots pour une session de quiz
  static List<WordVariant> selectForSession({
    required List<WordVariant> allWords,
    required Map<String, VariantProgress> progressMap,
    int sessionSize = 20,
    int maxNewWords = 5,
  }) {
    // Séparer nouveaux et à réviser
    var newWords = allWords.where((w) =>
        progressMap[w.id]?.timesShownAsQuestion == 0).toList();
    var reviewWords = allWords.where((w) =>
        progressMap[w.id]?.timesShownAsQuestion > 0).toList();

    // Trier par priorité
    reviewWords.sort((a, b) {
      var pa = progressMap[a.id]!;
      var pb = progressMap[b.id]!;
      return calculatePriority(
        masteryLevel: pb.masteryLevel,
        nextReviewDate: DateTime.tryParse(pb.nextReviewDate ?? ''),
      ).compareTo(calculatePriority(
        masteryLevel: pa.masteryLevel,
        nextReviewDate: DateTime.tryParse(pa.nextReviewDate ?? ''),
      ));
    });

    // Composer la session
    var session = <WordVariant>[];
    session.addAll(reviewWords.take(sessionSize - maxNewWords));
    session.addAll(newWords.take(maxNewWords));
    session.shuffle();

    return session.take(sessionSize).toList();
  }
}
```

### Algorithme de Validation des Réponses

```dart
class AnswerValidator {
  static const double similarityThreshold = 0.85;

  static ValidationResult validate({
    required String userAnswer,
    required List<String> acceptedAnswers,
    bool caseSensitive = false,
    bool accentSensitive = false,
  }) {
    String normalizedUser = _normalize(
      userAnswer,
      caseSensitive,
      accentSensitive
    );

    for (String accepted in acceptedAnswers) {
      String normalizedAccepted = _normalize(
        accepted,
        caseSensitive,
        accentSensitive
      );

      // Match exact
      if (normalizedUser == normalizedAccepted) {
        return ValidationResult(
          type: ValidationType.exact,
          message: 'Parfait !',
          similarity: 1.0,
        );
      }

      // Match par similarité
      double similarity = _calculateSimilarity(
        normalizedUser,
        normalizedAccepted
      );

      if (similarity >= similarityThreshold) {
        return ValidationResult(
          type: ValidationType.acceptable,
          message: 'Presque !',
          similarity: similarity,
        );
      }
    }

    return ValidationResult(
      type: ValidationType.incorrect,
      message: 'Incorrect. Réponse(s) attendue(s): ${acceptedAnswers.join(", ")}',
      similarity: 0.0,
    );
  }

  static String _normalize(String s, bool caseSensitive, bool accentSensitive) {
    String result = s.trim();
    if (!caseSensitive) result = result.toLowerCase();
    if (!accentSensitive) result = _removeAccents(result);
    return result;
  }

  static double _calculateSimilarity(String a, String b) {
    // Algorithme de Levenshtein normalisé
    int distance = _levenshteinDistance(a, b);
    int maxLen = max(a.length, b.length);
    return maxLen > 0 ? 1 - (distance / maxLen) : 1.0;
  }
}
```

---

## Gestion Audio

### Flux de Génération Audio

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│ Ajout mot   │────▶│ AudioService │────▶│ ElevenLabsService│
└─────────────┘     └──────────────┘     └─────────────────┘
                           │                      │
                           │                      ▼
                           │              ┌───────────────┐
                           │              │ API ElevenLabs│
                           │              └───────────────┘
                           │                      │
                           ▼                      ▼
                    ┌──────────────┐       ┌───────────────┐
                    │ Calcul Hash  │◀──────│ Bytes Audio   │
                    │    MD5       │       │    (MP3)      │
                    └──────────────┘       └───────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ Sauvegarde   │
                    │ Fichier Local│
                    └──────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │ MAJ DB avec  │
                    │ audio_hash   │
                    └──────────────┘
```

### Structure des Fichiers Audio

```
Documents/
└── VocabularyApp/
    └── audio/
        ├── a1b2c3d4e5f6...mp3  # Hash MD5 du texte+langue
        ├── f6e5d4c3b2a1...mp3
        └── ...
```

### Calcul du Hash

```dart
String calculateHash(String text, String langCode) {
  String input = '$text|$langCode';
  return md5.convert(utf8.encode(input)).toString();
}
```

---

## Tests E2E (Appium)

### Architecture

```
appium-tests/
├── features/                    # Scénarios Gherkin
│   ├── smoke.feature
│   ├── navigation.feature
│   └── vocabulary-lists.feature
├── step-definitions/            # Implémentation
│   ├── hooks.ts                 # Before/After
│   ├── common-steps.ts
│   ├── vocabulary-list-steps.ts
│   └── navigation-steps.ts
├── page-objects/                # Pattern POM
│   ├── BasePage.ts
│   ├── HomePage.ts
│   ├── ListDetailPage.ts
│   └── CreateListDialog.ts
└── types/
    └── appium-flutter-driver.d.ts
```

### Configuration Appium

```typescript
// Capabilities
const capabilities = {
  platformName: 'Android',
  'appium:deviceName': 'Android Emulator',
  'appium:automationName': 'Flutter',
  'appium:app': '/path/to/app-debug.apk',
  'appium:noReset': true,
};
```

### Page Object Pattern

```typescript
// BasePage.ts
export class BasePage {
  protected driver: Browser;

  async findByKey(key: string): Promise<any> {
    return await this.driver.execute(
      'flutter:waitFor',
      byValueKey(key),
      5000
    );
  }

  async clickByKey(key: string): Promise<void> {
    const finder = byValueKey(key);
    await this.driver.execute('flutter:waitFor', finder, 5000);
    await this.driver.elementClick(finder);
  }

  async enterTextByKey(key: string, text: string): Promise<void> {
    const finder = byValueKey(key);
    await this.driver.execute('flutter:waitFor', finder, 5000);
    await this.driver.elementSendKeys(finder, text);
  }
}
```

### Flutter Keys pour Tests

```dart
// home_screen.dart
Scaffold(
  key: const Key('home_screen'),
  appBar: AppBar(
    title: Text('Mes Listes', key: const Key('home_title')),
  ),
  floatingActionButton: FloatingActionButton.extended(
    key: const Key('add_list_button'),
    // ...
  ),
)
```

---

## Configuration

### Variables d'Environnement

```bash
# Build avec clés API
flutter build apk \
  --dart-define=ELEVENLABS_API_KEY=sk_xxx \
  --dart-define=OPENAI_API_KEY=sk-xxx \
  --dart-define=ANTHROPIC_API_KEY=sk-ant-xxx
```

### Modes de Déploiement

```dart
enum DeploymentMode {
  local,        // API directe + stockage local
  cloud,        // Backend centralisé
  localBackend, // Dev localhost
}

class AppConfig {
  static DeploymentMode mode = DeploymentMode.local;

  static AudioService createAudioService() {
    switch (mode) {
      case DeploymentMode.local:
        return LocalAudioService(ElevenLabsService());
      case DeploymentMode.cloud:
        return BackendAudioService();
      case DeploymentMode.localBackend:
        return BackendAudioService(baseUrl: 'http://localhost:3000');
    }
  }
}
```

---

## Dépendances Principales

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  # Base de données
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.3.0
  path_provider: ^2.1.0

  # Audio
  just_audio: ^0.9.35
  http: ^1.1.0
  crypto: ^3.0.3

  # Speech
  speech_to_text: ^6.3.0

  # Utils
  uuid: ^4.2.1
  shared_preferences: ^2.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_driver:
    sdk: flutter
```

---

## Commandes Utiles

```bash
# Lancer l'app (développement)
flutter run

# Lancer l'app pour tests Appium
flutter run --target=lib/main_appium.dart

# Build APK debug
flutter build apk --debug

# Build APK pour tests
flutter build apk --debug --target=lib/main_appium.dart

# Lancer tests E2E
cd appium-tests && npm test

# Lancer un test spécifique
npx cucumber-js features/smoke.feature
```

---

*Documentation technique générée le 21/01/2026*
