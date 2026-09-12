/// Grammar rule content — the data half of the grammar feature. Rules are
/// authored as JSON, one file per TARGET language
/// (`assets/seed/grammar/<lang>/rules.json`), reviewed + vector-verified, and
/// applied by a per-language GrammarLanguageModule. The rule carries WHAT to
/// teach (explanation, prerequisites) and the language module's parameters
/// (particle forms, irregular maps); HOW to apply them is code in the module.
///
/// Content fields (title/description/explanation, worked-example
/// translations) are locale maps; resolve them with [GrammarRule.title] etc.
/// (requested locale → en → first available).
library;

class GrammarRule {
  const GrammarRule({
    required this.id,
    required this.titles,
    required this.descriptions,
    required this.explanations,
    required this.workedExamples,
    required this.prerequisiteLists,
    required this.appliesToCategories,
    required this.minKnownWords,
    required this.mechanics,
    required this.testVectors,
  });

  final String id;
  final Map<String, String> titles;
  final Map<String, String> descriptions;
  final Map<String, String> explanations;
  final List<WorkedExample> workedExamples;

  /// Seed ids of the catalog lists (e.g. 'starter-greetings') that must be
  /// known collectively (≥80% across all prerequisites) before this rule
  /// unlocks. Legacy content may still carry display names; ruleStatuses
  /// matches both.
  final List<String> prerequisiteLists;

  /// Which word categories this rule's exercises draw from ('nom', 'verbe'…).
  final List<String> appliesToCategories;

  /// Minimum mastered words per category needed to generate a session.
  final Map<String, int> minKnownWords;

  final GrammarMechanics mechanics;
  final List<TestVector> testVectors;

  String title(String locale) => _resolve(titles, locale);
  String description(String locale) => _resolve(descriptions, locale);
  String explanation(String locale) => _resolve(explanations, locale);

  static String _resolve(Map<String, String> texts, String locale) =>
      texts[locale] ?? texts['en'] ?? (texts.isEmpty ? '' : texts.values.first);

  /// Parses both the current shape (locale maps, `worked_examples:
  /// [{target, translations}]`) and the legacy fr→ko one (`title_fr`,
  /// `[{ko, fr}]`) — the AI exercise cache may hold old payloads.
  factory GrammarRule.fromJson(Map<String, dynamic> json) {
    final r = json['rule'] as Map<String, dynamic>;
    return GrammarRule(
      id: r['id'] as String,
      titles: _localeMap(r, 'title'),
      descriptions: _localeMap(r, 'description'),
      explanations: _localeMap(r, 'explanation'),
      workedExamples: [
        for (final e in (r['worked_examples'] as List? ?? []))
          WorkedExample.fromJson(e as Map<String, dynamic>),
      ],
      prerequisiteLists: (r['prerequisite_lists'] as List).cast<String>(),
      appliesToCategories: (r['applies_to_categories'] as List).cast<String>(),
      minKnownWords: (r['min_known_words'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
      mechanics:
          GrammarMechanics.fromJson(r['mechanics'] as Map<String, dynamic>) ??
              const UnsupportedMechanics(),
      testVectors: [
        for (final v in (r['test_vectors'] as List? ?? []))
          TestVector(
            input: v['input'] as String,
            context: v['context'] as String? ?? '',
            expected: v['expected'] as String,
          ),
      ],
    );
  }

  static Map<String, String> _localeMap(Map<String, dynamic> r, String field) {
    final value = r[field];
    if (value is Map) return value.cast<String, String>();
    final legacy = r['${field}_fr'] as String?;
    return legacy == null ? const {} : {'fr': legacy};
  }
}

class WorkedExample {
  const WorkedExample({required this.target, required this.translations});

  /// The sentence in the studied language.
  final String target;

  /// Its translation per source locale.
  final Map<String, String> translations;

  String translation(String locale) =>
      translations[locale] ??
      translations['en'] ??
      (translations.isEmpty ? '' : translations.values.first);

  factory WorkedExample.fromJson(Map<String, dynamic> e) {
    if (e.containsKey('target')) {
      return WorkedExample(
        target: e['target'] as String,
        translations: (e['translations'] as Map<String, dynamic>? ?? {}).cast(),
      );
    }
    // Legacy fr→ko shape.
    return WorkedExample(
      target: e['ko'] as String,
      translations: {'fr': e['fr'] as String},
    );
  }
}

class TestVector {
  const TestVector(
      {required this.input, required this.context, required this.expected});
  final String input;
  final String context;
  final String expected;
}

/// The language-module parameters of a rule. Authoring shapes vary (a single
/// particle pair, named pairs, invariant particles with distinct meanings) —
/// they normalize here so the module sees one model.
sealed class GrammarMechanics {
  const GrammarMechanics();

  /// Null for unknown types: newer content on an older app must skip the
  /// rule, not crash the whole curriculum.
  static GrammarMechanics? fromJson(Map<String, dynamic> m) {
    switch (m['type'] as String) {
      case 'particle':
        final forms = m['particle_forms'] as Map<String, dynamic>;
        // Single pair: {after_consonant, after_vowel}. Named pairs: the same
        // shape nested one level down, keyed by variant name.
        if (forms.containsKey('after_consonant')) {
          return ParticleMechanics(variants: [
            ParticleVariant(
              key: 'default',
              afterConsonant: forms['after_consonant'] as String,
              afterVowel: forms['after_vowel'] as String,
            ),
          ]);
        }
        return ParticleMechanics(variants: [
          for (final entry in forms.entries)
            ParticleVariant(
              key: entry.key,
              afterConsonant: (entry.value as Map)['after_consonant'] as String,
              afterVowel: (entry.value as Map)['after_vowel'] as String,
            ),
        ]);
      case 'conjugation':
        final c = m['conjugation'] as Map<String, dynamic>;
        return ConjugationMechanics(
          irregulars: (c['irregulars'] as Map<String, dynamic>? ?? {})
              .cast<String, String>(),
          persons: (c['persons'] as List? ?? const []).cast<String>(),
        );
      case 'negation':
        final n = m['negation'] as Map<String, dynamic>? ?? {};
        return NegationMechanics(
          irregulars: (n['irregulars'] as Map<String, dynamic>? ?? {})
              .cast<String, String>(),
          pattern: n['pattern_template'] as String?,
        );
      case 'article':
        final a = m['article'] as Map<String, dynamic>;
        return ArticleMechanics(
          forms: (a['forms'] as Map<String, dynamic>).cast<String, String>(),
          overrides: (a['overrides'] as Map<String, dynamic>? ?? {})
              .cast<String, String>(),
        );
      case 'plural':
        final p = m['plural'] as Map<String, dynamic>? ?? {};
        return PluralMechanics(
          irregulars: (p['irregulars'] as Map<String, dynamic>? ?? {})
              .cast<String, String>(),
        );
      default:
        return null;
    }
  }
}

/// Placeholder for mechanics this app version cannot parse; rules carrying it
/// are filtered out at load time.
class UnsupportedMechanics extends GrammarMechanics {
  const UnsupportedMechanics();
}

class ParticleVariant {
  const ParticleVariant(
      {required this.key,
      required this.afterConsonant,
      required this.afterVowel});
  final String key;
  final String afterConsonant;
  final String afterVowel;
}

class ParticleMechanics extends GrammarMechanics {
  const ParticleMechanics({required this.variants});
  final List<ParticleVariant> variants;

  ParticleVariant variant(String? key) =>
      key == null ? variants.single : variants.firstWhere((v) => v.key == key);
}

class ConjugationMechanics extends GrammarMechanics {
  const ConjugationMechanics(
      {required this.irregulars, this.persons = const []});

  /// Lexical exceptions. Keys are either a bare word ('하다' — single-form
  /// languages) or 'word|person' ('sein|p1sg' — person-based languages).
  final Map<String, String> irregulars;

  /// Grammatical persons this rule drills ('p1sg', 'p2sg', 'p3sg'…), each
  /// becoming a drill variant. Empty for single-form languages (Korean).
  final List<String> persons;
}

class NegationMechanics extends GrammarMechanics {
  const NegationMechanics({required this.irregulars, this.pattern});
  final Map<String, String> irregulars;

  /// Wrap pattern with a `{verb}` placeholder ('no {verb}', '{verb} nicht',
  /// 'ne {verb} pas'), applied by the module to a conjugated form. Null for
  /// languages whose module hard-codes the composition (Korean's 안).
  final String? pattern;
}

class ArticleMechanics extends GrammarMechanics {
  const ArticleMechanics({required this.forms, this.overrides = const {}});

  /// Article per gender tag ('m'/'f'/'n'), or a single 'default' entry for
  /// ungendered languages (English a/an — phonology lives in the module).
  final Map<String, String> forms;

  /// Full expected phrase per word, for lexical exceptions the module's
  /// phonology can't derive (Spanish 'el agua', Italian 'lo studente'…).
  final Map<String, String> overrides;

  /// True when form selection needs a gender tag on the word.
  bool get gendered => !forms.containsKey('default');
}

class PluralMechanics extends GrammarMechanics {
  const PluralMechanics({required this.irregulars});
  final Map<String, String> irregulars;
}
