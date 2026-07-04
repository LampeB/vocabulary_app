/// Grammar rule content — the data half of the grammar feature. Rules are
/// authored as JSON (assets/seed/grammar_rules.json), reviewed + vector-
/// verified, and applied by a per-language GrammarLanguageModule. The rule
/// carries WHAT to teach (explanation, prerequisites) and the language
/// module's parameters (particle forms, irregular maps); HOW to apply them
/// is code in the module.
library;

class GrammarRule {
  const GrammarRule({
    required this.id,
    required this.titleFr,
    required this.descriptionFr,
    required this.explanationFr,
    required this.workedExamples,
    required this.prerequisiteLists,
    required this.appliesToCategories,
    required this.minKnownWords,
    required this.mechanics,
    required this.testVectors,
  });

  final String id;
  final String titleFr;
  final String descriptionFr;
  final String explanationFr;
  final List<WorkedExample> workedExamples;

  /// Names of the vocabulary lists that must be known (isListKnown ≥ 90%)
  /// before this rule unlocks.
  final List<String> prerequisiteLists;

  /// Which word categories this rule's exercises draw from ('nom', 'verbe'…).
  final List<String> appliesToCategories;

  /// Minimum mastered words per category needed to generate a session.
  final Map<String, int> minKnownWords;

  final GrammarMechanics mechanics;
  final List<TestVector> testVectors;

  factory GrammarRule.fromJson(Map<String, dynamic> json) {
    final r = json['rule'] as Map<String, dynamic>;
    return GrammarRule(
      id: r['id'] as String,
      titleFr: r['title_fr'] as String,
      descriptionFr: r['description_fr'] as String? ?? '',
      explanationFr: r['explanation_fr'] as String,
      workedExamples: [
        for (final e in (r['worked_examples'] as List? ?? []))
          WorkedExample(ko: e['ko'] as String, fr: e['fr'] as String),
      ],
      prerequisiteLists:
          (r['prerequisite_lists'] as List).cast<String>(),
      appliesToCategories:
          (r['applies_to_categories'] as List).cast<String>(),
      minKnownWords: (r['min_known_words'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
      mechanics: GrammarMechanics.fromJson(
          r['mechanics'] as Map<String, dynamic>),
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
}

class WorkedExample {
  const WorkedExample({required this.ko, required this.fr});
  final String ko;
  final String fr;
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

  static GrammarMechanics fromJson(Map<String, dynamic> m) {
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
              afterConsonant:
                  (entry.value as Map)['after_consonant'] as String,
              afterVowel: (entry.value as Map)['after_vowel'] as String,
            ),
        ]);
      case 'conjugation':
        final c = m['conjugation'] as Map<String, dynamic>;
        return ConjugationMechanics(
          irregulars: (c['irregulars'] as Map<String, dynamic>? ?? {})
              .cast<String, String>(),
        );
      case 'negation':
        final n = m['negation'] as Map<String, dynamic>? ?? {};
        return NegationMechanics(
          irregulars: (n['irregulars'] as Map<String, dynamic>? ?? {})
              .cast<String, String>(),
        );
      default:
        throw ArgumentError('unknown mechanics type: ${m['type']}');
    }
  }
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

  ParticleVariant variant(String? key) => key == null
      ? variants.single
      : variants.firstWhere((v) => v.key == key);
}

class ConjugationMechanics extends GrammarMechanics {
  const ConjugationMechanics({required this.irregulars});
  final Map<String, String> irregulars;
}

class NegationMechanics extends GrammarMechanics {
  const NegationMechanics({required this.irregulars});
  final Map<String, String> irregulars;
}
