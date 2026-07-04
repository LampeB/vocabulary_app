import 'dart:math';

import '../../domain/entities/grammar_rule.dart';
import 'grammar_language_module.dart';

/// A word available for exercise generation (mastered vocabulary, resolved
/// to the target-language word + its concept category).
class DrillWord {
  const DrillWord({required this.word, required this.category});
  final String word;
  final String category;
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

/// Stage-2 drill generation: word-level application of ONE rule to mastered
/// vocabulary. (Stage 3 — full-sentence composition mixing mastered rules —
/// replaces this generator's output as rules get mastered; it needs the
/// semantic annotation data.) Pure and deterministic given [random].
class GrammarDrillGenerator {
  const GrammarDrillGenerator(this._module);

  final GrammarLanguageModule _module;

  /// Words usable for [rule] (its categories, deduplicated).
  List<DrillWord> eligibleWords(GrammarRule rule, List<DrillWord> mastered) =>
      mastered
          .where((w) => rule.appliesToCategories.contains(w.category))
          .toList();

  /// Whether enough vocabulary is mastered to run a session at all.
  bool canGenerate(GrammarRule rule, List<DrillWord> mastered) {
    final byCategory = <String, int>{};
    for (final w in eligibleWords(rule, mastered)) {
      byCategory[w.category] = (byCategory[w.category] ?? 0) + 1;
    }
    return rule.minKnownWords.entries
        .every((e) => (byCategory[e.key] ?? 0) >= e.value);
  }

  /// Generates [count] exercises, cycling through eligible words (shuffled)
  /// and, for multi-variant particle rules, through the variants.
  List<GrammarExercise> generate(
    GrammarRule rule,
    List<DrillWord> mastered, {
    required int count,
    Random? random,
  }) {
    final words = eligibleWords(rule, mastered)..shuffle(random ?? Random());
    if (words.isEmpty) return const [];

    final variants = switch (rule.mechanics) {
      ParticleMechanics(:final variants) => variants,
      _ => const <ParticleVariant>[],
    };

    final exercises = <GrammarExercise>[];
    for (var i = 0; i < count; i++) {
      final word = words[i % words.length];
      final variant =
          variants.isEmpty ? null : variants[i % variants.length];
      final answer = _module.apply(rule, word.word,
          variantKey: variants.length > 1 ? variant!.key : null);

      final (promptKey, params) = switch (rule.mechanics) {
        ParticleMechanics() when variants.length > 1 => (
            'grammar.drill.particle_variant',
            {'word': word.word, 'hint': 'grammar.hint.${variant!.key}'},
          ),
        ParticleMechanics() => (
            'grammar.drill.particle',
            {'word': word.word, 'rule': rule.titleFr},
          ),
        ConjugationMechanics() => (
            'grammar.drill.conjugate',
            {'word': word.word},
          ),
        NegationMechanics() => (
            'grammar.drill.negate',
            {'word': word.word},
          ),
      };

      exercises.add(GrammarExercise(
        ruleId: rule.id,
        promptKey: promptKey,
        promptParams: params,
        expected: answer.expected,
        accepted: answer.accepted,
        variantKey: variants.length > 1 ? variant!.key : null,
      ));
    }
    return exercises;
  }
}
