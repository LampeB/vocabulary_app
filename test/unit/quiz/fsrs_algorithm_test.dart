import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';

/// FSRS is the spaced-repetition engine behind every progress/stats number.
/// It's pure and takes `now` as a parameter, so its state machine and intervals
/// are fully deterministic on the host.
void main() {
  final now = DateTime(2026, 7, 2, 10, 0);

  group('new card', () {
    test('again → learning, 1-day interval, first rep', () {
      final c = AppFsrs.schedule(const FsrsCard(), FsrsRating.again, now);
      expect(c.state, CardState.learning);
      expect(c.scheduledDays, 1);
      expect(c.reps, 1);
      expect(c.lapses, 0);
      expect(c.lastReview, now);
      expect(c.nextReview, now.add(const Duration(days: 1)));
      expect(c.stability, closeTo(0.4072, 0.0001)); // w[0]
    });

    test('good → still learning at 1 day', () {
      final c = AppFsrs.schedule(const FsrsCard(), FsrsRating.good, now);
      expect(c.state, CardState.learning);
      expect(c.scheduledDays, 1);
    });

    test('easy → graduates straight to review with a real interval', () {
      final c = AppFsrs.schedule(const FsrsCard(), FsrsRating.easy, now);
      expect(c.state, CardState.review);
      // _nextInterval(s) reduces to round(s); initial easy stability is w[3].
      expect(c.scheduledDays, 15);
      expect(c.reps, 1);
    });

    test('initial difficulty is always clamped to [1, 10]', () {
      for (final r in FsrsRating.values) {
        final c = AppFsrs.schedule(const FsrsCard(), r, now);
        expect(c.difficulty, inInclusiveRange(1.0, 10.0));
      }
    });
  });

  group('review card', () {
    FsrsCard reviewCard() => FsrsCard(
          stability: 20,
          difficulty: 5,
          state: CardState.review,
          reps: 5,
          lapses: 1,
          lastReview: now.subtract(const Duration(days: 10)),
        );

    test('again → relearning, lapse recorded, interval resets to 1 day', () {
      final c = AppFsrs.schedule(reviewCard(), FsrsRating.again, now);
      expect(c.state, CardState.relearning);
      expect(c.lapses, 2); // was 1
      expect(c.scheduledDays, 1);
      expect(c.reps, 6);
    });

    test('good → stays in review with a >= 1 day interval, no new lapse', () {
      final c = AppFsrs.schedule(reviewCard(), FsrsRating.good, now);
      expect(c.state, CardState.review);
      expect(c.lapses, 1); // unchanged
      expect(c.scheduledDays, greaterThanOrEqualTo(1));
    });

    test('easy schedules at least as far out as good', () {
      final good = AppFsrs.schedule(reviewCard(), FsrsRating.good, now);
      final easy = AppFsrs.schedule(reviewCard(), FsrsRating.easy, now);
      expect(easy.scheduledDays, greaterThanOrEqualTo(good.scheduledDays));
    });
  });

  group('corrupt restored rows (zeroed FSRS fields)', () {
    // Field bug 2026-07-07: progress rows pulled from the server were in
    // review state with stability/difficulty 0.0. The power-law math then
    // produced 0 × pow(0, -w9) = NaN and `.round()` threw
    // "Unsupported operation: Infinity or NaN toInt", silently killing
    // scheduling AND persistence for every review of those cards.
    FsrsCard zeroedCard(CardState state) => FsrsCard(
          stability: 0,
          difficulty: 0,
          state: state,
          reps: 3,
          lastReview: now.subtract(const Duration(days: 5)),
        );

    test('zeroed review card schedules without throwing, all fields finite',
        () {
      for (final state in CardState.values) {
        for (final r in FsrsRating.values) {
          final c = AppFsrs.schedule(zeroedCard(state), r, now);
          expect(c.stability.isFinite, isTrue, reason: 'state=$state r=$r');
          expect(c.stability, greaterThan(0), reason: 'state=$state r=$r');
          expect(c.difficulty.isFinite, isTrue, reason: 'state=$state r=$r');
          expect(c.scheduledDays, greaterThanOrEqualTo(1),
              reason: 'state=$state r=$r');
        }
      }
    });

    test('zeroed row self-heals: scheduled output is a valid input', () {
      var c = zeroedCard(CardState.review);
      // Two consecutive reviews — the second consumes the first's output.
      c = AppFsrs.schedule(c, FsrsRating.good, now);
      c = AppFsrs.schedule(c, FsrsRating.good, now.add(Duration(days: c.scheduledDays)));
      expect(c.stability.isFinite, isTrue);
      expect(c.stability, greaterThan(0));
      expect(c.difficulty, inInclusiveRange(1.0, 10.0));
    });

    test('NaN/Infinity in stored fields is also recovered', () {
      final c = AppFsrs.schedule(
        FsrsCard(
          stability: double.nan,
          difficulty: double.infinity,
          state: CardState.review,
          lastReview: now.subtract(const Duration(days: 2)),
        ),
        FsrsRating.good,
        now,
      );
      expect(c.stability.isFinite, isTrue);
      expect(c.difficulty, inInclusiveRange(1.0, 10.0));
      expect(c.scheduledDays, greaterThanOrEqualTo(1));
    });

    test('healthy cards are untouched by sanitizing', () {
      final healthy = FsrsCard(
        stability: 20,
        difficulty: 5,
        state: CardState.review,
        lastReview: now.subtract(const Duration(days: 10)),
      );
      final c = AppFsrs.schedule(healthy, FsrsRating.good, now);
      // Same result as the pre-sanitize algorithm for legal inputs:
      // stability grows on a successful review.
      expect(c.stability, greaterThan(20));
    });
  });

  test('every schedule keeps the interval >= 1 day', () {
    for (final state in CardState.values) {
      for (final r in FsrsRating.values) {
        final c = AppFsrs.schedule(
          FsrsCard(
              state: state,
              stability: 5,
              lastReview: now.subtract(const Duration(days: 3))),
          r,
          now,
        );
        expect(c.scheduledDays, greaterThanOrEqualTo(1),
            reason: 'state=$state rating=$r');
      }
    }
  });

  group('isMastered', () {
    VariantProgress p(CardState state, int scheduledDays) => VariantProgress(
          id: 'x',
          userId: 'u',
          variantId: 'v',
          direction: QuizDirection.frToKo,
          state: state,
          scheduledDays: scheduledDays,
          createdAt: now,
          updatedAt: now,
        );

    test('review + >= 21 scheduled days → mastered', () {
      expect(p(CardState.review, 21).isMastered, isTrue);
      expect(p(CardState.review, 30).isMastered, isTrue);
    });

    test('review but < 21 days → not mastered', () {
      expect(p(CardState.review, 20).isMastered, isFalse);
    });

    test('long interval but not yet in review → not mastered', () {
      expect(p(CardState.learning, 100).isMastered, isFalse);
      expect(p(CardState.newCard, 100).isMastered, isFalse);
    });
  });
}
