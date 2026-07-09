import '../languages.dart';

class AppConstants {
  // Content-language identity now lives in core/languages.dart (Languages).
  // These remain only for call sites not yet migrated by the
  // generic-language-pairs epic; do not add new uses.
  static const langFr = 'fr';
  static const langKo = 'ko';
  static List<String> get supportedLanguages => Languages.supported;

  static const fsrsDefaultStability = 1.0;
  static const fsrsDefaultDifficulty = 5.0;
  static const newCardsPerDay = 10;

  // 0.75 (was 0.82): spoken answers run through Whisper, whose near-miss
  // transcriptions of CORRECT answers land ~0.75-0.80 ("Restourant" vs
  // "restaurant" = 0.78, field log 2026-07-10) — 0.82 sent them to the
  // repeat loop. Typing keeps the stricter bar.
  static const fuzzyThresholdDriving = 0.75;
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
