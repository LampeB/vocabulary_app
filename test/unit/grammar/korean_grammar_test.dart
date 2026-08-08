import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/grammar/grammar_language_module.dart';
import 'package:vocab_kr/core/grammar/korean/korean_morphology.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';

/// The Korean grammar engine, proven against the REAL rule content: every
/// test vector in assets/seed/grammar/ko/rules.json (author-reviewed, ~70 of
/// them) must come out of the module exactly right. Plus direct morphology
/// cases for the algorithmic paths (no irregular map).

/// Maps a vector's French context note to the particle-variant key.
String? variantFor(GrammarRule rule, String context) {
  final m = rule.mechanics;
  if (m is! ParticleMechanics || m.variants.length == 1) return null;
  final c = context.toLowerCase();
  if (c.contains('sujet')) return 'subject';
  if (c.contains('objet')) return 'object';
  if (c.contains('destination') || c.contains('temps')) {
    return 'destination_or_time';
  }
  return 'action_location';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<GrammarRule> rules;
  late KoreanGrammarModule module;

  setUpAll(() async {
    final raw =
        await rootBundle.loadString('assets/seed/grammar/ko/rules.json');
    rules = [
      for (final j in (jsonDecode(raw) as Map<String, dynamic>)['rules']
          as List)
        GrammarRule.fromJson(j as Map<String, dynamic>),
    ];
    final conjugation = rules
        .firstWhere((r) => r.mechanics is ConjugationMechanics)
        .mechanics as ConjugationMechanics;
    module =
        KoreanGrammarModule(conjugationIrregulars: conjugation.irregulars);
  });

  test('the bundled content parses: 5 rules, every one with vectors', () {
    expect(rules, hasLength(5));
    for (final r in rules) {
      expect(r.testVectors.length, greaterThanOrEqualTo(12),
          reason: '${r.id} is under-specified');
      expect(r.explanation('fr'), isNotEmpty);
      expect(r.prerequisiteLists, isNotEmpty);
    }
  });

  test('EVERY authored test vector passes through the module', () {
    var checked = 0;
    for (final rule in rules) {
      for (final v in rule.testVectors) {
        final answer = module.apply(rule, v.input,
            variantKey: variantFor(rule, v.context));
        expect(answer.expected, v.expected,
            reason: '${rule.id}: ${v.input} (${v.context})');
        expect(answer.accepted, contains(v.expected));
        checked++;
      }
    }
    expect(checked, greaterThanOrEqualTo(70));
  });

  group('morphology — algorithmic paths (no irregulars map)', () {
    String conj(String w) => KoreanMorphology.presentPolite(w);

    test('batchim stems follow vowel harmony', () {
      expect(conj('먹다'), '먹어요');
      expect(conj('읽다'), '읽어요');
      expect(conj('살다'), '살아요');
      expect(conj('맛있다'), '맛있어요');
      expect(conj('받다'), '받아요'); // regular ㄷ — no false irregularity
    });

    test('vowel contractions', () {
      expect(conj('가다'), '가요');
      expect(conj('오다'), '와요');
      expect(conj('보다'), '봐요');
      expect(conj('마시다'), '마셔요');
      expect(conj('배우다'), '배워요');
      expect(conj('보내다'), '보내요');
      expect(conj('서다'), '서요');
      expect(conj('되다'), '돼요');
    });

    test('ㅡ-drop takes harmony from the previous syllable', () {
      expect(conj('바쁘다'), '바빠요'); // 바 is bright → 아
      expect(conj('배고프다'), '배고파요'); // 고 is bright... 프's prev is 고? — 파
      expect(conj('크다'), '커요'); // no previous syllable → 어
    });

    test('하다 compounds conjugate to 해요', () {
      expect(conj('하다'), '해요');
      expect(conj('공부하다'), '공부해요');
      expect(conj('좋아하다'), '좋아해요');
    });

    test('lexical irregulars require the override map (by design)', () {
      // Without the map the regular algorithm applies — this is exactly why
      // irregularity is data (per-word), not code.
      expect(conj('듣다'), isNot('들어요'));
      expect(KoreanMorphology.presentPolite('듣다', irregulars: {'듣다': '들어요'}),
          '들어요');
    });

    test('particle attachment follows batchim', () {
      String topic(String w) => KoreanMorphology.attachParticle(w,
          afterConsonant: '은', afterVowel: '는');
      expect(topic('학생'), '학생은');
      expect(topic('친구'), '친구는');
      expect(KoreanMorphology.hasBatchim('물'), isTrue);
      expect(KoreanMorphology.hasBatchim('커피'), isFalse);
    });

    test('negation: compounds split, others prefix', () {
      expect(KoreanMorphology.negatePresent('공부하다'), '공부 안 해요');
      expect(KoreanMorphology.negatePresent('가다'), '안 가요');
      expect(
          KoreanMorphology.negatePresent('좋아하다',
              irregulars: {'좋아하다': '안 좋아해요'}),
          '안 좋아해요');
    });
  });

  test('pedagogical negation override still accepts the mechanical form', () {
    final negation =
        rules.firstWhere((r) => r.mechanics is NegationMechanics);
    final answer = module.apply(negation, '맛있다');
    expect(answer.expected, '맛없어요'); // the antonym, per the authored content
    expect(answer.accepted, contains('안 맛있어요')); // grammatical form accepted
  });
}
