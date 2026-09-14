import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';

QuizCard _card(String id, {bool requeue = false}) => QuizCard(
      progress: VariantProgress(
        id: 'progress-$id',
        userId: 'user',
        variantId: id,
        direction: QuizDirection.frToKo,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      questionWord: 'question-$id',
      answerWords: ['answer-$id'],
      isRequeue: requeue,
    );

void main() {
  test('session metrics distinguish planned cards from requeued review cards',
      () {
    final first = _card('first');
    final second = _card('second');
    final replay = _card('first', requeue: true);
    final state = QuizState(
      cards: [first, second, replay],
      currentIndex: 2,
      correctCount: 1,
    );

    expect(state.currentCard, replay);
    expect(state.nextCard, isNull);
    expect(state.total, 3);
    expect(state.displayTotal, 2);
    expect(state.position, 2);
    expect(state.accuracy, .5);
    expect(state.inReviewTail, isTrue);
    expect(state.reviewPosition, 1);
    expect(state.reviewTotal, 1);
  });

  test('empty and in-progress sessions expose safe card and accuracy values',
      () {
    expect(const QuizState().currentCard, isNull);
    expect(const QuizState().nextCard, isNull);
    expect(const QuizState().accuracy, 0);

    final first = _card('first');
    final second = _card('second');
    final state = QuizState(cards: [first, second]);
    expect(state.currentCard, first);
    expect(state.nextCard, second);
    expect(state.position, 1);
    expect(state.inReviewTail, isFalse);
  });
}
