class AppConstants {
  // Codes des langues
  static const String lang1Code = 'fr';
  static const String lang2Code = 'ko';
  
  // Noms des langues pour l'affichage
  static const Map<String, String> languageNames = {
    'fr': 'Français',
    'ko': '한국어 (Coréen)',
    'en': 'English',
    'ja': '日本語',
    'es': 'Español',
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
