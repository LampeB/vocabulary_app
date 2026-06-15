import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/answer_validator.dart';

void main() {
  group('AnswerValidator.validate', () {
    group('empty input', () {
      test('blank string is always incorrect', () {
        final r = AnswerValidator.validate(
          userAnswer: '   ',
          acceptedAnswers: ['Bonjour'],
        );
        expect(r.isCorrect, false);
        expect(r.type, ValidationResultType.incorrect);
      });
    });

    group('exact match', () {
      test('identical string is exact', () {
        final r = AnswerValidator.validate(
          userAnswer: 'Bonjour',
          acceptedAnswers: ['Bonjour'],
        );
        expect(r.isCorrect, true);
        expect(r.type, ValidationResultType.exact);
      });

      test('case-insensitive match is exact', () {
        final r = AnswerValidator.validate(
          userAnswer: 'bonjour',
          acceptedAnswers: ['Bonjour'],
        );
        expect(r.isCorrect, true);
        expect(r.type, ValidationResultType.exact);
      });

      test('Korean exact match', () {
        final r = AnswerValidator.validate(
          userAnswer: '안녕하세요',
          acceptedAnswers: ['안녕하세요'],
        );
        expect(r.isCorrect, true);
        expect(r.type, ValidationResultType.exact);
      });

      test('accented string matches itself exactly', () {
        final r = AnswerValidator.validate(
          userAnswer: 'déjà',
          acceptedAnswers: ['déjà'],
        );
        expect(r.isCorrect, true);
        expect(r.type, ValidationResultType.exact);
      });
    });

    group('multiple accepted answers', () {
      test('accepts any word in the list', () {
        final r = AnswerValidator.validate(
          userAnswer: '안녕',
          acceptedAnswers: ['안녕하세요', '안녕'],
        );
        expect(r.isCorrect, true);
        expect(r.matchedWord, '안녕');
      });

      test('matchedWord reflects the best match', () {
        final r = AnswerValidator.validate(
          userAnswer: 'merci',
          acceptedAnswers: ['Merci', 'Au revoir'],
        );
        expect(r.isCorrect, true);
        expect(r.matchedWord, 'Merci');
      });
    });

    group('fuzzy matching (Dice-coefficient bigrams, threshold 0.85)', () {
      // 'bonjours' vs 'bonjour': Dice = 2*6/13 ≈ 0.923 — clearly above threshold
      test('extra trailing char is correctable', () {
        final r = AnswerValidator.validate(
          userAnswer: 'bonjours',
          acceptedAnswers: ['Bonjour'],
        );
        expect(r.isCorrect, true);
      });

      // Very different word: Dice well below any threshold
      test('completely wrong answer is incorrect', () {
        final r = AnswerValidator.validate(
          userAnswer: 'pizza',
          acceptedAnswers: ['Bonjour'],
        );
        expect(r.isCorrect, false);
        expect(r.type, ValidationResultType.incorrect);
      });

      test('closer match has higher score than distant match', () {
        final close = AnswerValidator.validate(
          userAnswer: 'bonjours',
          acceptedAnswers: ['Bonjour'],
        );
        final far = AnswerValidator.validate(
          userAnswer: 'bonsoir',
          acceptedAnswers: ['Bonjour'],
        );
        expect(close.score, greaterThan(far.score));
      });
    });

    group('driving mode (lower threshold 0.82)', () {
      test('driving mode accepts the same valid answers as typing mode', () {
        // 'bonjours' has Dice ≈ 0.923, accepted in both modes
        final r = AnswerValidator.validate(
          userAnswer: 'bonjours',
          acceptedAnswers: ['Bonjour'],
          isDrivingMode: true,
        );
        expect(r.isCorrect, true);
      });
    });

    group('score field', () {
      test('exact match has score close to 1.0', () {
        final r = AnswerValidator.validate(
          userAnswer: 'Bonjour',
          acceptedAnswers: ['Bonjour'],
        );
        expect(r.score, greaterThanOrEqualTo(0.98));
      });

      test('wrong answer has lower score than correct answer', () {
        final correct = AnswerValidator.validate(
          userAnswer: 'Bonjour',
          acceptedAnswers: ['Bonjour'],
        );
        final wrong = AnswerValidator.validate(
          userAnswer: 'pizza',
          acceptedAnswers: ['Bonjour'],
        );
        expect(correct.score, greaterThan(wrong.score));
      });
    });
  });
}
