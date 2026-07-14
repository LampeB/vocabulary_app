import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';

/// The answer auto-speak policy (shouldSpeakAnswer) is a spec'd behavioural rule:
/// flashcard + typing are silent (typing has an on-demand button), voice speaks, hands-free speaks only on a
/// wrong answer. Pure function → host-side unit test (no device audio needed).
void main() {
  group('shouldSpeakAnswer', () {
    test('flashcard never speaks, right or wrong', () {
      expect(shouldSpeakAnswer(QuizMode.flashcard, correct: true), isFalse);
      expect(shouldSpeakAnswer(QuizMode.flashcard, correct: false), isFalse);
    });

    test('typing NEVER auto-speaks (on-demand speaker button instead, 2026-07-14)', () {
      expect(shouldSpeakAnswer(QuizMode.typing, correct: true), isFalse);
      expect(shouldSpeakAnswer(QuizMode.typing, correct: false), isFalse);
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
