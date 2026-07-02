import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';

/// The answer auto-speak policy (shouldSpeakAnswer) is a spec'd behavioural rule:
/// flashcard is silent, typing/voice always speak, hands-free speaks only on a
/// wrong answer. Pure function → host-side unit test (no device audio needed).
void main() {
  group('shouldSpeakAnswer', () {
    test('flashcard never speaks, right or wrong', () {
      expect(shouldSpeakAnswer(QuizMode.flashcard, correct: true), isFalse);
      expect(shouldSpeakAnswer(QuizMode.flashcard, correct: false), isFalse);
    });

    test('typing always speaks', () {
      expect(shouldSpeakAnswer(QuizMode.typing, correct: true), isTrue);
      expect(shouldSpeakAnswer(QuizMode.typing, correct: false), isTrue);
    });

    test('voice always speaks', () {
      expect(shouldSpeakAnswer(QuizMode.voice, correct: true), isTrue);
      expect(shouldSpeakAnswer(QuizMode.voice, correct: false), isTrue);
    });

    test('hands-free speaks only when the answer was wrong', () {
      expect(shouldSpeakAnswer(QuizMode.handsFree, correct: true), isFalse);
      expect(shouldSpeakAnswer(QuizMode.handsFree, correct: false), isTrue);
    });
  });
}
