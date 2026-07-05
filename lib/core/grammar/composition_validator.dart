import '../../domain/entities/grammar_rule.dart';
import 'composition_exercise.dart';
import 'grammar_drill_generator.dart';
import 'grammar_language_module.dart';

/// Mechanical sanity checks on AI-generated composition exercises.
///
/// The AI does the semantic work (which words fit together); the local
/// morphology engine stays the source of truth for what it CAN verify:
/// an exercise survives only if its expected answer contains at least one
/// known word transformed correctly per the target rule's mechanics. This
/// drops hallucinated-vocabulary and wrong-morphology items without ever
/// rejecting a sentence for meaning (which the engine can't judge).
class CompositionValidator {
  CompositionValidator(this._module);

  final GrammarLanguageModule _module;

  List<CompositionExercise> filter(
    GrammarRule rule,
    List<DrillWord> knownWords,
    List<CompositionExercise> exercises,
  ) =>
      [
        for (final e in exercises)
          if (_isValid(rule, knownWords, e)) e,
      ];

  bool _isValid(
    GrammarRule rule,
    List<DrillWord> knownWords,
    CompositionExercise e,
  ) {
    if (e.accepted.isEmpty) return false;

    // The expected sentence must contain a known word correctly transformed
    // by the target rule (any particle variant counts).
    final eligible = knownWords
        .where((w) => rule.appliesToCategories.contains(w.category));
    for (final w in eligible) {
      final variantKeys = switch (rule.mechanics) {
        ParticleMechanics(:final variants) => [for (final v in variants) v.key],
        _ => <String?>[null],
      };
      for (final key in variantKeys) {
        try {
          final answer = _module.apply(rule, w.word, variantKey: key);
          if (answer.accepted.any(e.expected.contains)) return true;
        } catch (_) {
          // Word/rule combination the module can't transform — try the next.
        }
      }
    }
    return false;
  }
}
