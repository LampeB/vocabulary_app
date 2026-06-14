class AppConstants {
  static const langFr = 'fr';
  static const langKo = 'ko';
  static const supportedLanguages = [langFr, langKo];

  static const fsrsDefaultStability = 1.0;
  static const fsrsDefaultDifficulty = 5.0;
  static const newCardsPerDay = 10;

  static const fuzzyThresholdDriving = 0.82;
  static const fuzzyThresholdTyping = 0.85;
  static const jamoFuzzyThreshold = 0.80;

  static const maxAudioCacheMb = 500;
  static const audioSampleRate = 16000;

  static const sttSilenceThresholdMs = 1500;
  static const sttMaxRecordingMs = 6000;
  static const sttAmplitudeGateDbfs = -40.0;
  static const sttMaxConsecutiveFailures = 5;

  static const leaderboardScoreCapPerDay = 200;
  static const streakGoalCardsPerDay = 5;

  static const registerNeutral = 'neutral';
  static const registerFormal = 'formal';
  static const registerInformal = 'informal';
  static const registerVeryInformal = 'very_informal';
  static const registerTags = [
    registerNeutral,
    registerFormal,
    registerInformal,
    registerVeryInformal,
  ];

  static const conceptCategories = [
    'daily_life', 'food', 'travel', 'work', 'family',
    'body', 'nature', 'emotions', 'numbers', 'colors',
    'time', 'clothes', 'housing', 'technology', 'other',
  ];

  static const rcPremiumEntitlement = 'premium';
  static const rcMonthlyProduct = 'vocab_kr_premium_monthly';
  static const rcAnnualProduct = 'vocab_kr_premium_annual';
}
