import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/answer_validator.dart';

/// AnswerValidator drives every typing/voice verdict. Coverage found the
/// STT-oriented passes untested: the multi-word transcript pass and the two
/// Korean particle-strip passes (prefix match, trailing-strip).
void main() {
  ValidationResult validate(String user, List<String> accepted,
          {bool driving = false}) =>
      AnswerValidator.validate(
          userAnswer: user,
          acceptedAnswers: accepted,
          isDrivingMode: driving);

  group('base verdicts', () {
    test('empty transcript → incorrect', () {
      final r = validate('   ', ['chat']);
      expect(r.isCorrect, isFalse);
      expect(r.type, ValidationResultType.incorrect);
    });

    test('exact match → exact, matchedWord set', () {
      final r = validate('chat', ['chat', 'minou']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.exact);
      expect(r.matchedWord, 'chat');
      expect(r.score, 1.0);
    });

    test('case, accents and whitespace are normalized away', () {
      final r = validate('  Éléphant ', ['elephant']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.exact);
    });

    test('near-miss above 0.90 → acceptable', () {
      // "bibliothequ" vs "bibliotheque": one char short → dice ≈ 0.95.
      final r = validate('bibliothequ', ['bibliothèque']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.acceptable);
    });

    test('near-miss between threshold and 0.90 → typo', () {
      // "bibliotheqe" vs "bibliotheque": dice ≈ 0.857 → in [0.85, 0.90).
      final r = validate('bibliotheqe', ['bibliothèque']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.typo);
    });

    test('unrelated word → incorrect with the best score reported', () {
      final r = validate('voiture', ['chat']);
      expect(r.isCorrect, isFalse);
      expect(r.type, ValidationResultType.incorrect);
    });

    test('best of several accepted answers wins', () {
      final r = validate('minou', ['chat', 'minou']);
      expect(r.isCorrect, isTrue);
      expect(r.matchedWord, 'minou');
    });
  });

  group('multi-word transcript pass (STT gives a sentence)', () {
    test('the answer buried in a longer transcript is found word-by-word', () {
      // Whole-string similarity of "le petit chat" vs "chat" is far below the
      // threshold; the per-word pass matches "chat" exactly.
      final r = validate('le petit chat', ['chat']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.exact);
      expect(r.matchedWord, 'chat');
    });

    test('a sentence with no matching word stays incorrect', () {
      final r = validate('une grande maison', ['chat']);
      expect(r.isCorrect, isFalse);
    });
  });

  group('Korean particle passes (STT appends particles)', () {
    test('prefix pass: transcript = answer + particle → exact', () {
      // User said 사과, STT transcribed 사과를 (object particle appended).
      final r = validate('사과를', ['사과']);
      expect(r.isCorrect, isTrue);
      expect(r.type, ValidationResultType.exact);
      expect(r.score, 1.0);
      expect(r.matchedWord, '사과');
    });

    test(
        'trailing-strip pass: single-char answer + particle → exact '
        '(prefix pass requires ≥ 2 chars, so this exercises the strip loop)',
        () {
      // 물 (water) + 을 → prefix check is skipped (answer < 2 chars), the
      // 1-char strip re-score finds the exact match.
      final r = validate('물을', ['물']);
      expect(r.isCorrect, isTrue);
      expect(r.score, 1.0);
      expect(r.matchedWord, '물');
    });

    test('unrelated Korean word is still rejected after all passes', () {
      final r = validate('바나나', ['사과']);
      expect(r.isCorrect, isFalse);
      expect(r.type, ValidationResultType.incorrect);
    });
  });
}
