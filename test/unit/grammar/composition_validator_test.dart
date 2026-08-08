import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/grammar/composition_exercise.dart';
import 'package:vocab_kr/core/grammar/composition_validator.dart';
import 'package:vocab_kr/core/grammar/grammar_drill_generator.dart';
import 'package:vocab_kr/core/grammar/grammar_language_module.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';

/// The AI generates composition exercises; the LOCAL morphology engine stays
/// the judge of what it can verify mechanically. An exercise survives only
/// if its expected answer contains a known word correctly transformed by the
/// target rule — hallucinated vocabulary and wrong morphology are dropped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<GrammarRule> rules;
  late CompositionValidator validator;

  const known = [
    DrillWord(word: '학생', category: 'nom'),
    DrillWord(word: '물', category: 'nom'),
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
    validator = CompositionValidator(
        KoreanGrammarModule(conjugationIrregulars: conjugation.irregulars));
  });

  GrammarRule rule(String idPrefix) =>
      rules.firstWhere((r) => r.id.startsWith(idPrefix));

  CompositionExercise ex(String expected, {List<String>? accepted}) =>
      CompositionExercise(
        prompt: 'Une phrase en français',
        expected: expected,
        accepted: accepted ?? [expected],
      );

  test('keeps a sentence where the rule is applied to a known word', () {
    final kept = validator.filter(rule('particule-theme'), known, [
      ex('학생은 물 마셔요'), // 학생 + 은 — correct topic particle
    ]);
    expect(kept, hasLength(1));
  });

  test('drops a sentence built on hallucinated vocabulary', () {
    final kept = validator.filter(rule('particule-theme'), known, [
      ex('고래는 헤엄쳐요'), // 고래 is not a known word
    ]);
    expect(kept, isEmpty);
  });

  test('drops a sentence where the particle is morphologically wrong', () {
    final kept = validator.filter(rule('particule-theme'), known, [
      ex('학생는 물 마셔요'), // 학생 has batchim → 은, never 는
    ]);
    expect(kept, isEmpty);
  });

  test('conjugation rule: a correctly conjugated known verb passes', () {
    final kept = validator.filter(rule('present-poli'), known, [
      ex('학생은 물 먹어요'), // 먹다 → 먹어요 (correct harmony)
      ex('학생은 물 먹아요'), // wrong harmony — dropped
    ]);
    expect(kept, hasLength(1));
    expect(kept.single.expected, contains('먹어요'));
  });

  test('mixed batch: only the mechanically sound items survive', () {
    final kept = validator.filter(rule('particule-theme'), known, [
      ex('물은 차가워요'), // 물 + 은 ✓ (차가워요 is beyond the engine — allowed)
      ex('커피가 좋아요'), // 커피 not in known words here
      ex('학생은 가요', accepted: ['학생은 가요', '가요']),
    ]);
    expect(kept, hasLength(2));
  });

  group('CompositionExercise.fromJson', () {
    test('parses a valid item and guarantees expected ∈ accepted', () {
      final e = CompositionExercise.fromJson({
        'prompt': 'Je vais',
        'expected': '가요',
        'accepted': ['저는 가요'],
      })!;
      expect(e.accepted, contains('가요'));
      expect(e.accepted, contains('저는 가요'));
    });

    test('rejects malformed items instead of crashing', () {
      expect(CompositionExercise.fromJson(null), isNull);
      expect(CompositionExercise.fromJson('nope'), isNull);
      expect(CompositionExercise.fromJson({'prompt': ''}), isNull);
      expect(
          CompositionExercise.fromJson({'prompt': 'p', 'expected': 42}),
          isNull);
    });
  });
}
