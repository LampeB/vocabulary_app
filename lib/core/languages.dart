import 'package:easy_localization/easy_localization.dart';

/// Single source of truth for CONTENT languages — the languages being
/// *studied*, a separate axis from the 7 UI locales. Part of the
/// generic-language-pairs epic: adding a studyable language must be
/// data-only — an entry here plus a `lang.<code>` key per translation file.
/// No 'fr'/'ko' literals may drive language logic anywhere else.
abstract final class Languages {
  /// BCP-47 locale per content langCode, for the speech services (STT/TTS).
  static const Map<String, String> _speechLocales = {
    'fr': 'fr-FR',
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

  /// i18n key for a language's display name (content langs and UI locales
  /// share the same `lang.<code>` keys).
  static String displayNameKey(String langCode) => 'lang.$langCode';

  /// Localized display name; falls back to the raw code for unknown languages.
  static String displayName(String langCode) {
    final key = displayNameKey(langCode);
    final name = key.tr();
    return name == key ? langCode : name;
  }
}
