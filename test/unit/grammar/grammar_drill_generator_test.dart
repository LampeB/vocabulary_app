import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/grammar/grammar_drill_generator.dart';
import 'package:vocab_kr/core/grammar/grammar_language_module.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';

/// Stage-2 drill generation: exercises are built at runtime from the rule +
/// mastered words — correct answers via the module, only eligible categories,
/// variants cycled, minimums enforced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<GrammarRule> rules;
  late GrammarDrillGenerator generator;

  const mastered = [
    DrillWord(word: '학생', category: 'nom'),
    DrillWord(word: '친구', category: 'nom'),
    DrillWord(word: '물', category: 'nom'),
    DrillWord(word: '커피', category: 'nom'),
    DrillWord(word: '밥', category: 'nom'),
    DrillWord(word: '학교', category: 'lieu'),
    DrillWord(word: '먹다', category: 'verbe'),
    DrillWord(word: '가다', category: 'verbe'),
  ];

  setUpAll(() async {
    final raw =
        await rootBundle.loadString('assets/seed/grammar/ko/rules.json');
    rules = [
      for (final j in (jsonDecode(raw) as Map<String, dynamic>)['rules']
          as List)
        GrammarRule.fromJson(j as Map<String, dynamic>),
    ];
    final conjugation = rules
        .map((r) => r.mechanics)
        .whereType<ConjugationMechanics>()
        .first;
    generator = GrammarDrillGenerator(
        KoreanGrammarModule(conjugationIrregulars: conjugation.irregulars));
  });

  GrammarRule rule(String idPrefix) =>
      rules.firstWhere((r) => r.id.startsWith(idPrefix));

  test('particle drills apply the rule correctly to eligible words', () {
    final exercises = generator.generate(rule('particule-theme'), mastered,
        count: 8, random: Random(1));

    expect(exercises, hasLength(8));
    for (final e in exercises) {
      // Only nom/lieu words are used, and the answer is word+correct particle.
      expect(e.expected, anyOf(endsWith('은'), endsWith('는')));
      expect(e.promptParams['word'], isNotNull);
      expect(e.expected, startsWith(e.promptParams['word']!));
    }
  });

  test('multi-variant rules cycle variants and label the hint', () {
    final exercises = generator.generate(
        rule('particules-sujet'), mastered,
        count: 6, random: Random(2));

    final keys = exercises.map((e) => e.variantKey).toSet();
    expect(keys, {'subject', 'object'});
    for (final e in exercises) {
      expect(e.promptKey, 'grammar.drill.particle_variant');
      expect(e.promptParams['hint'], 'grammar.hint.${e.variantKey}');
    }
  });

  test('conjugation drills use only verbs and conjugate correctly', () {
    final exercises = generator.generate(rule('present-poli'), mastered,
        count: 6, random: Random(3));

    for (final e in exercises) {
      expect(['먹다', '가다'], contains(e.promptParams['word']));
      expect(e.expected, anyOf('먹어요', '가요'));
    }
  });

  test('canGenerate enforces the per-category minimums', () {
    // present-poli needs 5 verbs; only 2 mastered here.
    expect(generator.canGenerate(rule('present-poli'), mastered), isFalse);
    // theme particle needs 5 noms; we have 5.
    expect(generator.canGenerate(rule('particule-theme'), mastered), isTrue);
  });

  test('no eligible words → no exercises (never crashes)', () {
    final onlyVerbs = [const DrillWord(word: '먹다', category: 'verbe')];
    expect(
        generator.generate(rule('particule-theme'), onlyVerbs, count: 5),
        isEmpty);
  });
}
