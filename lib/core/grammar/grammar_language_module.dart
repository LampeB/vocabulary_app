import '../../domain/entities/grammar_rule.dart';
import 'korean/korean_morphology.dart';

/// Per-language grammar plugin — the boundary that keeps the grammar feature
/// language-pluggable (pressure-tested against a 20-language roadmap; see the
/// session-architecture epic in Notion). Everything OUTSIDE this interface —
/// rule model, gating, progress, session flow, semantic tags on concepts —
/// is language-agnostic. Everything language-specific (morphology, word
/// order, validation tolerance) lives in an implementation.
///
/// Deliberately grows with the feature: `apply` ships now; the sentence
/// composer adds `orderConstituents(...)` (a FUNCTION — German V2 and Irish
/// VSO rule out a static role list) and a validation hook (Korean's jamo
/// similarity becomes the first implementation).
abstract class GrammarLanguageModule {
  String get langCode;

  /// Applies [rule] to a single [word] and returns the expected answer plus
  /// accepted alternatives. [variantKey] selects among a rule's variants
  /// (particle 'subject'/'object', conjugation persons 'p1sg'…); [tags]
  /// carries the word's grammatical metadata (gender) for mechanics that
  /// need it (articles).
  GrammarAnswer apply(GrammarRule rule, String word,
      {String? variantKey, List<String> tags = const []});
}

class GrammarAnswer {
  const GrammarAnswer({required this.expected, required this.accepted});

  final String expected;

  /// All answers the validator should accept — always includes [expected].
  final List<String> accepted;
}

class KoreanGrammarModule implements GrammarLanguageModule {
  /// [conjugationIrregulars] is the merged lexical-irregularity map (today
  /// from the conjugation rule's content; later per-word grammar metadata).
  /// Negation composes on top of conjugation, so it needs the same map.
  const KoreanGrammarModule({this.conjugationIrregulars = const {}});

  final Map<String, String> conjugationIrregulars;

  @override
  String get langCode => 'ko';

  @override
  GrammarAnswer apply(GrammarRule rule, String word,
      {String? variantKey, List<String> tags = const []}) {
    switch (rule.mechanics) {
      case ParticleMechanics(:final variants):
        final v = variantKey == null && variants.length == 1
            ? variants.single
            : variants.firstWhere((p) => p.key == variantKey,
                orElse: () => throw ArgumentError(
                    'rule ${rule.id} needs a variantKey among '
                    '${variants.map((p) => p.key).toList()}'));
        final answer = KoreanMorphology.attachParticle(
          word,
          afterConsonant: v.afterConsonant,
          afterVowel: v.afterVowel,
        );
        return GrammarAnswer(expected: answer, accepted: [answer]);

      case ConjugationMechanics(:final irregulars):
        final answer = KoreanMorphology.presentPolite(word,
            irregulars: {...conjugationIrregulars, ...irregulars});
        return GrammarAnswer(expected: answer, accepted: [answer]);

      case NegationMechanics(:final irregulars):
        final merged = {...conjugationIrregulars};
        final answer = KoreanMorphology.negatePresent(word,
            irregulars: irregulars, conjugationIrregulars: merged);
        final mechanical = KoreanMorphology.mechanicalNegation(word,
            conjugationIrregulars: merged);
        // A pedagogical override (맛있다 → 맛없어요, the antonym) still accepts
        // the strictly grammatical form (안 맛있어요).
        return GrammarAnswer(
          expected: answer,
          accepted: answer == mechanical ? [answer] : [answer, mechanical],
        );

      case UnsupportedMechanics():
      case ArticleMechanics():
      case PluralMechanics():
        // Not part of Korean's curriculum; loaders filter unsupported rules
        // out before drills are generated.
        throw StateError(
            'rule ${rule.id}: mechanics not supported by the ko module');
    }
  }
}
