import 'package:easy_localization/easy_localization.dart';

/// Single source of truth for CONTENT languages — the languages being
/// *studied*, a separate axis from the 7 UI locales. Part of the
/// generic-language-pairs epic: adding a studyable language must be
/// data-only — an entry here plus a `lang.<code>` key per translation file.
/// No 'fr'/'ko' literals may drive language logic anywhere else.
abstract final class Languages {
  /// BCP-47 locale per content langCode, for the speech services (STT/TTS).
  /// Adding an entry here is what makes a language studyable (plus a
  /// `lang.<code>` key per translation file, and — for premium voice — an
  /// ElevenLabs voice id in [ElevenLabsService]).
  static const Map<String, String> _speechLocales = {
    'fr': 'fr-FR',
    'en': 'en-US',
    'it': 'it-IT',
    'de': 'de-DE',
    'es': 'es-ES',
    'ko': 'ko-KR',
  };

  /// The content languages the app can study today.
  static List<String> get supported =>
      _speechLocales.keys.toList(growable: false);

  /// BCP-47 locale for STT/TTS. Falls back to the langCode itself so an
  /// unmapped language degrades gracefully (engine picks its own region)
  /// instead of silently becoming French.
  static String speechLocaleFor(String langCode) =>
      _speechLocales[langCode] ?? langCode;

  /// Flag emoji per content langCode, for compact language chips/labels.
  static const Map<String, String> _flags = {
    'fr': '🇫🇷',
    'en': '🇬🇧',
    'it': '🇮🇹',
    'de': '🇩🇪',
    'es': '🇪🇸',
    'ko': '🇰🇷',
    'ja': '🇯🇵',
  };

  /// Flag emoji for [langCode]; a neutral white flag for unknown languages.
  static String flagFor(String langCode) => _flags[langCode] ?? '🏳️';

  /// i18n key for a language's display name (content langs and UI locales
  /// share the same `lang.<code>` keys).
  static String displayNameKey(String langCode) => 'lang.$langCode';

  /// Localized display name; falls back to the raw code for unknown languages.
  static String displayName(String langCode) {
    final key = displayNameKey(langCode);
    final name = key.tr();
    return name == key ? langCode : name;
  }

  /// The writing system a content language renders in. Drives font selection
  /// (Hangul needs Noto Sans KR; Latin uses the app's Latin stack) and lets
  /// answer-scoring pick script-appropriate tolerance. Replaces the pervasive
  /// binary `isKorean` checks. Extend as non-Latin languages are added
  /// (ja → kana/kanji, zh → han, ru → cyrillic…).
  static Script scriptFor(String langCode) => switch (langCode) {
        'ko' => Script.hangul,
        _ => Script.latin,
      };

  /// True when [langCode] is written in Hangul and needs the Korean font +
  /// jamo-aware answer scoring. The single source of truth for what used to be
  /// scattered `langCode == 'ko'` / `isKorean` conditionals.
  static bool usesHangul(String langCode) =>
      scriptFor(langCode) == Script.hangul;
}

/// Writing systems the app can render/score. Font stack and answer-validation
/// tolerance branch on this rather than on individual language codes.
enum Script { latin, hangul }
