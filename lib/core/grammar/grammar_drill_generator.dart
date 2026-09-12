import 'dart:math';

import '../../domain/entities/grammar_rule.dart';
import 'grammar_language_module.dart';

/// A word available for exercise generation (mastered vocabulary, resolved
/// to the target-language word + its concept category and grammar tags).
class DrillWord {
  const DrillWord(
      {required this.word, required this.category, this.tags = const []});
  final String word;
  final String category;

  /// Grammatical metadata from word_variants.context_tags ('m'/'f'/'n'…).
  final List<String> tags;
}

/// One generated exercise. The prompt is an i18n key + params so the prompt
/// language follows the UI locale — nothing about the prompt is hardcoded to
/// French (20-language roadmap).
class GrammarExercise {
  const GrammarExercise({
    required this.ruleId,
    required this.promptKey,
    required this.promptParams,
    required this.expected,
    required this.accepted,
    this.variantKey,
  });

  final String ruleId;
  final String promptKey;
  final Map<String, String> promptParams;
  final String expected;
  final List<String> accepted;
  final String? variantKey;
}

/// Word-level application of one rule to mastered vocabulary. The generator
/// is deliberately local and deterministic: grammar drills never depend on a
/// runtime LLM or network response.
class GrammarDrillGenerator {
  const GrammarDrillGenerator(this._module);

  final GrammarLanguageModule _module;

  /// Words usable for [rule]: its categories, and — for gendered mechanics
  /// (articles, gender-driven plurals) — only words carrying one of the
  /// gender tags the rule's forms need. Untagged words (proper nouns) are
  /// deliberately excluded from gendered drills.
  List<DrillWord> eligibleWords(GrammarRule rule, List<DrillWord> mastered) {
    final requiredTags = switch (rule.mechanics) {
      ArticleMechanics(:final forms, gendered: true) => forms.keys.toSet(),
      _ => const <String>{},
    };
    return mastered
        .where((w) => rule.appliesToCategories.contains(w.category))
        // Compound display words ('riz / repas', 'mañana (parte del día)')
        // don't inflect as one token — keep them out of morphology drills.
        .where((w) => !w.word.contains('/') && !w.word.contains('('))
        .where((w) =>
            requiredTags.isEmpty || w.tags.any((t) => requiredTags.contains(t)))
        .toList();
  }

  /// Whether enough vocabulary is mastered to run a session at all.
  bool canGenerate(GrammarRule rule, List<DrillWord> mastered) {
    final byCategory = <String, int>{};
    for (final w in eligibleWords(rule, mastered)) {
      byCategory[w.category] = (byCategory[w.category] ?? 0) + 1;
    }
    return rule.minKnownWords.entries
        .every((e) => (byCategory[e.key] ?? 0) >= e.value);
  }

  /// The drill variants of [rule]: particle variants and conjugation persons
  /// both cycle the same way (variantKey per exercise).
  List<String> _variantKeys(GrammarRule rule) => switch (rule.mechanics) {
        ParticleMechanics(:final variants) when variants.length > 1 => [
            for (final v in variants) v.key,
          ],
        ConjugationMechanics(:final persons) when persons.isNotEmpty => persons,
        _ => const [],
      };

  /// Generates [count] exercises, cycling through eligible words (shuffled)
  /// and through the rule's variants (particle forms, persons).
  List<GrammarExercise> generate(
    GrammarRule rule,
    List<DrillWord> mastered, {
    required int count,
    Random? random,
    String promptLocale = 'en',
  }) {
    if (rule.mechanics is UnsupportedMechanics) return const [];
    final words = eligibleWords(rule, mastered)..shuffle(random ?? Random());
    if (words.isEmpty) return const [];

    final variantKeys = _variantKeys(rule);

    final exercises = <GrammarExercise>[];
    for (var i = 0; i < count; i++) {
      final word = words[i % words.length];
      final variantKey =
          variantKeys.isEmpty ? null : variantKeys[i % variantKeys.length];
      final answer = _module.apply(rule, word.word,
          variantKey: variantKey, tags: word.tags);

      final (promptKey, params) = switch (rule.mechanics) {
        ParticleMechanics() when variantKey != null => (
            'grammar.drill.particle_variant',
            {'word': word.word, 'hint': 'grammar.hint.$variantKey'},
          ),
        ParticleMechanics() => (
            'grammar.drill.particle',
            {'word': word.word, 'rule': rule.title(promptLocale)},
          ),
        ConjugationMechanics() when variantKey != null => (
            'grammar.drill.conjugate_person',
            {'word': word.word, 'hint': 'grammar.hint.$variantKey'},
          ),
        ConjugationMechanics() => (
            'grammar.drill.conjugate',
            {'word': word.word},
          ),
        NegationMechanics() => (
            'grammar.drill.negate',
            {'word': word.word},
          ),
        ArticleMechanics() => (
            'grammar.drill.article',
            {'word': word.word, 'rule': rule.title(promptLocale)},
          ),
        PluralMechanics() => (
            'grammar.drill.plural',
            {'word': word.word},
          ),
        UnsupportedMechanics() => throw StateError('unreachable'),
      };

      exercises.add(GrammarExercise(
        ruleId: rule.id,
        promptKey: promptKey,
        promptParams: params,
        expected: answer.expected,
        accepted: answer.accepted,
        variantKey: variantKey,
      ));
    }
    return exercises;
  }
}
