import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

/// The starter-content catalog (multi-language seed epic).
///
/// Content scales per LANGUAGE, not per pair: a language-agnostic registry
/// (`assets/seed/vocab/registry.json`) names the curriculum lists and their
/// concepts, and one layer file per language
/// (`assets/seed/vocab/lang/<code>.json`) carries that language's words,
/// example sentences and teaching notes. Any ordered pair (source, target) is
/// composed at seed time by [StarterSeeder] from the two layers.
class SeedCatalog {
  const SeedCatalog({required this.lists, required this.conceptCategories});

  final List<SeedList> lists;

  /// Registry concept id → category ('nom', 'verbe', 'expression', …).
  final Map<String, String?> conceptCategories;

  static const registryAsset = 'assets/seed/vocab/registry.json';

  static Future<SeedCatalog> load(AssetBundle bundle) async {
    final raw =
        jsonDecode(await bundle.loadString(registryAsset)) as Map<String, dynamic>;
    final lists = [
      for (final l in (raw['lists'] as List).cast<Map<String, dynamic>>())
        SeedList(
          id: l['id'] as String,
          nameKey: l['name_key'] as String,
          descKey: l['desc_key'] as String,
          targetLangs: (l['target_langs'] as List?)?.cast<String>(),
          conceptIds: (l['concepts'] as List).cast<String>(),
        ),
    ];
    final categories = {
      for (final c in (raw['concepts'] as List).cast<Map<String, dynamic>>())
        c['id'] as String: c['category'] as String?,
    };
    return SeedCatalog(lists: lists, conceptCategories: categories);
  }

  /// The curriculum lists that exist when studying [targetLang] —
  /// universal lists plus any scoped to that language (e.g. the Korean
  /// particles list only exists for ko).
  List<SeedList> listsForTarget(String targetLang) => [
        for (final l in lists)
          if (l.targetLangs == null || l.targetLangs!.contains(targetLang)) l,
      ];
}

class SeedList {
  const SeedList({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.targetLangs,
    required this.conceptIds,
  });

  final String id;
  final String nameKey;
  final String descKey;

  /// Null = universal (seeded for every target language).
  final List<String>? targetLangs;
  final List<String> conceptIds;

  /// Stable identity of this list once seeded for a pair.
  String seedIdFor(String source, String target) => '$id:$source>$target';
}

/// One language's content layer: words, examples and notes per concept id.
class SeedLanguageLayer {
  const SeedLanguageLayer({required this.lang, required this.entries});

  final String lang;
  final Map<String, SeedEntry> entries;

  static String assetFor(String lang) => 'assets/seed/vocab/lang/$lang.json';

  static Future<SeedLanguageLayer> load(AssetBundle bundle, String lang) async {
    final raw = jsonDecode(await bundle.loadString(assetFor(lang)))
        as Map<String, dynamic>;
    final entries = <String, SeedEntry>{};
    for (final MapEntry(key: id, value: e)
        in (raw['entries'] as Map<String, dynamic>).entries) {
      final map = e as Map<String, dynamic>;
      entries[id] = SeedEntry(
        words: [
          for (final w in (map['words'] as List).cast<Map<String, dynamic>>())
            SeedWord(
              word: w['word'] as String,
              isPrimary: w['is_primary'] as bool? ?? false,
              position: w['position'] as int? ?? 0,
              tags: (w['tags'] as List?)?.cast<String>() ?? const [],
            ),
        ],
        example: map['example'] as String?,
        notes: (map['notes'] as Map<String, dynamic>?)?.cast<String, String>() ??
            const {},
      );
    }
    return SeedLanguageLayer(lang: raw['lang'] as String? ?? lang, entries: entries);
  }
}

class SeedEntry {
  const SeedEntry({required this.words, this.example, this.notes = const {}});

  final List<SeedWord> words;

  /// Example sentence in this layer's language.
  final String? example;

  /// Teaching notes about this word, keyed by the READER's language — used
  /// when this layer is the studied (target) language: notes[sourceLang].
  final Map<String, String> notes;

  SeedWord? get primary {
    for (final w in words) {
      if (w.isPrimary) return w;
    }
    return words.isEmpty ? null : words.first;
  }

  /// Note for a learner whose language is [sourceLang]; English fallback.
  String? noteFor(String sourceLang) => notes[sourceLang] ?? notes['en'];
}

class SeedWord {
  const SeedWord({
    required this.word,
    required this.isPrimary,
    required this.position,
    this.tags = const [],
  });

  final String word;
  final bool isPrimary;
  final int position;

  /// Grammatical metadata ('f', 'm', 'n', …) consumed by grammar drills via
  /// word_variants.context_tags.
  final List<String> tags;
}

/// Resolves `seed.list.*` display strings from the bundled translation files,
/// trying [localePriority] in order. Reads the assets directly (instead of
/// easy_localization) so seeding stays headless-safe and deterministic.
class SeedTranslations {
  const SeedTranslations(this._maps);

  final List<Map<String, dynamic>> _maps;

  static Future<SeedTranslations> load(
      AssetBundle bundle, List<String> localePriority) async {
    final maps = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final locale in localePriority) {
      final code = locale.split('_').first;
      if (!seen.add(code)) continue;
      try {
        maps.add(jsonDecode(await bundle.loadString(
            'assets/translations/$code.json')) as Map<String, dynamic>);
      } catch (_) {
        // Not a UI locale (or missing file) — try the next candidate.
      }
    }
    return SeedTranslations(maps);
  }

  String resolve(String key) {
    for (final map in _maps) {
      final value = map[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return key;
  }
}
