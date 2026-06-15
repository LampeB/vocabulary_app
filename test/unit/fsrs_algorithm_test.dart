import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';

void main() {
  final now = DateTime(2025, 6, 1);

  group('AppFsrs.schedule — new card', () {
    const newCard = FsrsCard();

    test('Again → learning state, 1-day interval', () {
      final next = AppFsrs.schedule(newCard, FsrsRating.again, now);
      expect(next.state, CardState.learning);
      expect(next.scheduledDays, 1);
      expect(next.reps, 1);
    });

    test('Hard → learning state, 1-day interval', () {
      final next = AppFsrs.schedule(newCard, FsrsRating.hard, now);
      expect(next.state, CardState.learning);
      expect(next.scheduledDays, 1);
    });

    test('Good → learning state, 1-day interval', () {
      final next = AppFsrs.schedule(newCard, FsrsRating.good, now);
      expect(next.state, CardState.learning);
    });

    test('Easy → review state, multi-day interval', () {
      final next = AppFsrs.schedule(newCard, FsrsRating.easy, now);
      expect(next.state, CardState.review);
      expect(next.scheduledDays, greaterThan(1));
    });

    test('nextReview is set relative to now', () {
      final next = AppFsrs.schedule(newCard, FsrsRating.good, now);
      expect(next.nextReview, isNotNull);
      expect(next.lastReview, now);
    });

    test('stability is positive after first rating', () {
      for (final rating in FsrsRating.values) {
        final next = AppFsrs.schedule(newCard, rating, now);
        expect(next.stability, greaterThan(0), reason: 'rating=$rating');
      }
    });

    test('difficulty stays in [1, 10] for all ratings', () {
      for (final rating in FsrsRating.values) {
        final next = AppFsrs.schedule(newCard, rating, now);
        expect(next.difficulty, greaterThanOrEqualTo(1.0), reason: 'rating=$rating');
        expect(next.difficulty, lessThanOrEqualTo(10.0), reason: 'rating=$rating');
      }
    });
  });

  group('AppFsrs.schedule — learning card', () {
    final learningCard = FsrsCard(
      state: CardState.learning,
      stability: 1.0,
      difficulty: 5.0,
      reps: 1,
      lastReview: now.subtract(const Duration(days: 1)),
    );

    test('Again keeps in learning', () {
      final next = AppFsrs.schedule(learningCard, FsrsRating.again, now);
      expect(next.state, CardState.learning);
    });

    test('Good graduates to review', () {
      final next = AppFsrs.schedule(learningCard, FsrsRating.good, now);
      expect(next.state, CardState.review);
      expect(next.scheduledDays, greaterThanOrEqualTo(1));
    });

    test('Easy graduates to review', () {
      final next = AppFsrs.schedule(learningCard, FsrsRating.easy, now);
      expect(next.state, CardState.review);
    });

    test('rep count increments', () {
      final next = AppFsrs.schedule(learningCard, FsrsRating.good, now);
      expect(next.reps, learningCard.reps + 1);
    });
  });

  group('AppFsrs.schedule — review card', () {
    final reviewCard = FsrsCard(
      state: CardState.review,
      stability: 10.0,
      difficulty: 5.0,
      reps: 5,
      lastReview: now.subtract(const Duration(days: 10)),
    );

    test('Again → relearning, lapses increment', () {
      final next = AppFsrs.schedule(reviewCard, FsrsRating.again, now);
      expect(next.state, CardState.relearning);
      expect(next.lapses, reviewCard.lapses + 1);
    });

    test('Good → stays in review', () {
      final next = AppFsrs.schedule(reviewCard, FsrsRating.good, now);
      expect(next.state, CardState.review);
      expect(next.lapses, reviewCard.lapses);
    });

    test('Easy → longer interval than Good', () {
      final easy = AppFsrs.schedule(reviewCard, FsrsRating.easy, now);
      final good = AppFsrs.schedule(reviewCard, FsrsRating.good, now);
      expect(easy.scheduledDays, greaterThanOrEqualTo(good.scheduledDays));
    });

    test('stability increases on successful recall', () {
      final next = AppFsrs.schedule(reviewCard, FsrsRating.good, now);
      expect(next.stability, greaterThan(reviewCard.stability));
    });
  });

  group('AppFsrs.schedule — relearning card', () {
    final relearningCard = FsrsCard(
      state: CardState.relearning,
      stability: 2.0,
      difficulty: 7.0,
      reps: 6,
      lapses: 2,
      lastReview: now.subtract(const Duration(days: 1)),
    );

    test('Again stays in relearning', () {
      final next = AppFsrs.schedule(relearningCard, FsrsRating.again, now);
      expect(next.state, CardState.relearning);
    });

    test('Good graduates back to review', () {
      final next = AppFsrs.schedule(relearningCard, FsrsRating.good, now);
      expect(next.state, CardState.review);
    });
  });

  group('FsrsCard.retrievability', () {
    test('new card has 0 retrievability', () {
      const card = FsrsCard();
      expect(card.retrievability, 0);
    });

    test('recently reviewed card has high retrievability', () {
      // retrievability getter uses DateTime.now() internally, so lastReview
      // must be relative to actual wall-clock time, not the fixed 'now'.
      final card = FsrsCard(
        state: CardState.review,
        stability: 1000.0, // very high stability → slow decay
        lastReview: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(card.retrievability, greaterThan(0.95));
    });
  });

  group('difficulty stays clamped over many ratings', () {
    test('repeated Easy does not push difficulty below 1', () {
      var card = const FsrsCard();
      for (var i = 0; i < 30; i++) {
        card = AppFsrs.schedule(card, FsrsRating.easy, now);
      }
      expect(card.difficulty, greaterThanOrEqualTo(1.0));
    });

    test('repeated Again does not push difficulty above 10', () {
      var card = const FsrsCard();
      for (var i = 0; i < 30; i++) {
        card = AppFsrs.schedule(card, FsrsRating.again, now);
      }
      expect(card.difficulty, lessThanOrEqualTo(10.0));
    });
  });
}
