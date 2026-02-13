class AppConstants {
  // Noms des langues pour l'affichage
  static const Map<String, String> languageNames = {
    'fr': 'Français',
    'ko': 'Coréen',
    'en': 'Anglais',
    'es': 'Espagnol',
    'de': 'Allemand',
    'it': 'Italien',
    'pt': 'Portugais',
    'ja': 'Japonais',
    'zh': 'Chinois',
    'ru': 'Russe',
    'ar': 'Arabe',
    'nl': 'Néerlandais',
    'pl': 'Polonais',
    'tr': 'Turc',
    'sv': 'Suédois',
  };

  // Drapeaux des langues
  static const Map<String, String> languageFlags = {
    'fr': '\u{1F1EB}\u{1F1F7}',
    'ko': '\u{1F1F0}\u{1F1F7}',
    'en': '\u{1F1EC}\u{1F1E7}',
    'es': '\u{1F1EA}\u{1F1F8}',
    'de': '\u{1F1E9}\u{1F1EA}',
    'it': '\u{1F1EE}\u{1F1F9}',
    'pt': '\u{1F1F5}\u{1F1F9}',
    'ja': '\u{1F1EF}\u{1F1F5}',
    'zh': '\u{1F1E8}\u{1F1F3}',
    'ru': '\u{1F1F7}\u{1F1FA}',
    'ar': '\u{1F1F8}\u{1F1E6}',
    'nl': '\u{1F1F3}\u{1F1F1}',
    'pl': '\u{1F1F5}\u{1F1F1}',
    'tr': '\u{1F1F9}\u{1F1F7}',
    'sv': '\u{1F1F8}\u{1F1EA}',
  };

  // Niveaux de registre
  static const String registerFormal = 'formal';
  static const String registerNeutral = 'neutral';
  static const String registerInformal = 'informal';
  static const String registerVeryInformal = 'very_informal';
  
  static const List<String> registerLevels = [
    registerFormal,
    registerNeutral,
    registerInformal,
    registerVeryInformal,
  ];

  static const Map<String, String> registerDisplayNames = {
    registerFormal: 'Formel',
    registerNeutral: 'Neutre',
    registerInformal: 'Informel',
    registerVeryInformal: 'Très informel',
  };

  // Directions d'apprentissage
  static const String directionLang1ToLang2 = 'lang1_to_lang2';
  static const String directionLang2ToLang1 = 'lang2_to_lang1';

  // Paramètres SRS (Spaced Repetition System)
  static const double masteryThreshold = 0.7; // 70% = mot connu
  static const List<int> srsIntervals = [1, 3, 7, 14, 30, 90]; // jours
  static const double easeFactor = 2.5;
  static const double minEaseFactor = 1.3;
  static const double maxEaseFactor = 3.0;

  // Paramètres de quiz
  static const int defaultQuizSize = 20;
  static const int minQuizSize = 5;
  static const int maxQuizSize = 50;
  static const int newWordsPerSession = 5; // Nouveaux mots par session

  // Validation de réponse
  static const double similarityThreshold = 0.85; // 85% de similarité minimum
  static const bool caseSensitive = false;
  static const bool accentSensitive = false;

  // Audio
  static const String audioExtension = '.mp3';
  static const int audioSampleRate = 44100;
  static const String audioFolder = 'audio';

  // Statuts de téléchargement
  static const String downloadStatusIdle = 'idle';
  static const String downloadStatusDownloading = 'downloading';
  static const String downloadStatusCompleted = 'completed';
  static const String downloadStatusError = 'error';

  // Catégories prédéfinies
  static const List<String> predefinedCategories = [
    'greetings',      // Salutations
    'food',           // Nourriture
    'transport',      // Transport
    'anatomy',        // Anatomie
    'numbers',        // Nombres
    'time',           // Temps
    'colors',         // Couleurs
    'family',         // Famille
    'work',           // Travail
    'hobbies',        // Loisirs
    'travel',         // Voyage
    'shopping',       // Shopping
    'health',         // Santé
    'emotions',       // Émotions
    'weather',        // Météo
  ];

  static const Map<String, String> categoryDisplayNames = {
    'greetings': '👋 Salutations',
    'food': '🍜 Nourriture',
    'transport': '🚗 Transport',
    'anatomy': '🫀 Anatomie',
    'numbers': '🔢 Nombres',
    'time': '⏰ Temps',
    'colors': '🎨 Couleurs',
    'family': '👨‍👩‍👧‍👦 Famille',
    'work': '💼 Travail',
    'hobbies': '🎯 Loisirs',
    'travel': '✈️ Voyage',
    'shopping': '🛍️ Shopping',
    'health': '🏥 Santé',
    'emotions': '😊 Émotions',
    'weather': '🌤️ Météo',
  };

  // Paramètres d'affichage
  static const int maxRecentLists = 5;
  static const int resultsPerPage = 20;
  
  // Durées (en millisecondes)
  static const int feedbackDisplayDuration = 1500;
  static const int audioPlaybackTimeout = 5000;
  static const int apiRequestTimeout = 10000;

  // Messages
  static const String appName = 'VocabApp';
  static const String appVersion = '1.0.0';
  static const String noInternetMessage = 'Pas de connexion Internet';
  static const String loadingMessage = 'Chargement...';
  static const String errorMessage = 'Une erreur est survenue';
}
