import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_app/utils/answer_validator.dart';

void main() {
  group('AnswerValidator - exact matches', () {
    test('exact match returns correct with score 1.0', () {
      final result = AnswerValidator.validate(
        userAnswer: 'hello',
        expectedAnswers: [
          {'word': 'hello', 'register_tag': 'neutral'}
        ],
      );

      expect(result.isCorrect, true);
      expect(result.similarityScore, 1.0);
      expect(result.type, ValidationResultType.exact);
    });

    test('case-insensitive match works', () {
      final result = AnswerValidator.validate(
        userAnswer: 'HELLO',
        expectedAnswers: [
          {'word': 'hello', 'register_tag': 'neutral'}
        ],
      );

      expect(result.isCorrect, true);
      expect(result.similarityScore, 1.0);
    });

    test('whitespace is trimmed', () {
      final result = AnswerValidator.validate(
        userAnswer: '  hello  ',
        expectedAnswers: [
          {'word': 'hello', 'register_tag': 'neutral'}
        ],
      );

      expect(result.isCorrect, true);
      expect(result.similarityScore, 1.0);
    });
  });

  group('AnswerValidator - similarity matching', () {
    test('high similarity answer is accepted', () {
      final result = AnswerValidator.validate(
        userAnswer: 'bonjourr', // Small typo
        expectedAnswers: [
          {'word': 'bonjour', 'register_tag': 'neutral'}
        ],
        tolerance: 0.85,
      );

      expect(result.isCorrect, true);
      expect(result.type, ValidationResultType.acceptable);
    });

    test('low similarity answer is rejected', () {
      final result = AnswerValidator.validate(
        userAnswer: 'goodbye',
        expectedAnswers: [
          {'word': 'bonjour', 'register_tag': 'neutral'}
        ],
      );

      expect(result.isCorrect, false);
      expect(result.type, ValidationResultType.incorrect);
    });
  });

  group('AnswerValidator - multiple expected answers', () {
    test('matches any of the expected answers', () {
      final result = AnswerValidator.validate(
        userAnswer: 'hi',
        expectedAnswers: [
          {'word': 'hello', 'register_tag': 'neutral'},
          {'word': 'hi', 'register_tag': 'informal'},
          {'word': 'hey', 'register_tag': 'very_informal'},
        ],
      );

      expect(result.isCorrect, true);
      expect(result.similarityScore, 1.0);
    });

    test('finds best match among multiple options', () {
      final result = AnswerValidator.validate(
        userAnswer: 'helo', // Typo
        expectedAnswers: [
          {'word': 'hello', 'register_tag': 'neutral'},
          {'word': 'hi', 'register_tag': 'informal'},
        ],
        tolerance: 0.75,
      );

      expect(result.isCorrect, true);
      expect(result.similarityScore, greaterThan(0.75));
    });
  });

  group('AnswerValidator - empty answers', () {
    test('empty answer is rejected', () {
      final result = AnswerValidator.validate(
        userAnswer: '',
        expectedAnswers: [
          {'word': 'hello', 'register_tag': 'neutral'}
        ],
      );

      expect(result.isCorrect, false);
      expect(result.similarityScore, 0.0);
      expect(result.feedback, contains('Aucune réponse'));
    });

    test('whitespace-only answer is rejected', () {
      final result = AnswerValidator.validate(
        userAnswer: '   ',
        expectedAnswers: [
          {'word': 'hello', 'register_tag': 'neutral'}
        ],
      );

      expect(result.isCorrect, false);
      expect(result.similarityScore, 0.0);
    });
  });

  group('AnswerValidator - quality feedback', () {
    test('excellent score returns "Excellent !"', () {
      final feedback = AnswerValidator.getQualityFeedback(0.98);
      expect(feedback, 'Excellent !');
    });

    test('good score returns appropriate feedback', () {
      final feedback = AnswerValidator.getQualityFeedback(0.92);
      expect(feedback, 'Très bien !');
    });

    test('acceptable score returns "Bien !"', () {
      final feedback = AnswerValidator.getQualityFeedback(0.88);
      expect(feedback, 'Bien !');
    });

    test('poor score returns "Incorrect"', () {
      final feedback = AnswerValidator.getQualityFeedback(0.40);
      expect(feedback, 'Incorrect');
    });
  });

  group('AnswerValidator - register compatibility', () {
    test('same registers are compatible', () {
      expect(
        AnswerValidator.areRegistersCompatible('formal', 'formal'),
        true,
      );
    });

    test('neutral is compatible with any register', () {
      expect(
        AnswerValidator.areRegistersCompatible('neutral', 'formal'),
        true,
      );
      expect(
        AnswerValidator.areRegistersCompatible('informal', 'neutral'),
        true,
      );
    });

    test('null registers are compatible', () {
      expect(
        AnswerValidator.areRegistersCompatible(null, 'formal'),
        true,
      );
      expect(
        AnswerValidator.areRegistersCompatible('formal', null),
        true,
      );
    });

    test('different non-neutral registers are incompatible', () {
      expect(
        AnswerValidator.areRegistersCompatible('formal', 'informal'),
        false,
      );
    });
  });

  group('AnswerValidator - findMatchingVariants', () {
    test('finds exact matches', () {
      final variants = [
        {'id': '1', 'word': 'hello'},
        {'id': '2', 'word': 'hi'},
        {'id': '3', 'word': 'hey'},
      ];

      final matches = AnswerValidator.findMatchingVariants(
        userAnswer: 'hello',
        allVariants: variants,
      );

      expect(matches, contains('1'));
      expect(matches.length, 1);
    });

    test('finds similar matches with tolerance', () {
      final variants = [
        {'id': '1', 'word': 'bonjour'},
        {'id': '2', 'word': 'salut'},
      ];

      final matches = AnswerValidator.findMatchingVariants(
        userAnswer: 'bonjourr', // Typo
        allVariants: variants,
        tolerance: 0.85,
      );

      expect(matches, contains('1'));
    });

    test('returns empty list when no matches', () {
      final variants = [
        {'id': '1', 'word': 'hello'},
        {'id': '2', 'word': 'hi'},
      ];

      final matches = AnswerValidator.findMatchingVariants(
        userAnswer: 'goodbye',
        allVariants: variants,
      );

      expect(matches, isEmpty);
    });
  });

  group('AnswerValidator - accent handling', () {
    test('handles accented characters', () {
      final result = AnswerValidator.validate(
        userAnswer: 'été',
        expectedAnswers: [
          {'word': 'été', 'register_tag': 'neutral'}
        ],
      );

      expect(result.isCorrect, true);
    });

    test('handles Korean characters', () {
      final result = AnswerValidator.validate(
        userAnswer: '안녕하세요',
        expectedAnswers: [
          {'word': '안녕하세요', 'register_tag': 'formal'}
        ],
      );

      expect(result.isCorrect, true);
    });
  });
}
