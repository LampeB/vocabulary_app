import 'dart:math';

enum CardState { newCard, learning, review, relearning }

enum FsrsRating { again, hard, good, easy }

class FsrsCard {
  const FsrsCard({
    this.stability = 0,
    this.difficulty = AppFsrs.initialDifficulty,
    this.elapsedDays = 0,
    this.scheduledDays = 0,
    this.reps = 0,
    this.lapses = 0,
    this.state = CardState.newCard,
    this.lastReview,
    this.nextReview,
  });

  final double stability;
  final double difficulty;
  final int elapsedDays;
  final int scheduledDays;
  final int reps;
  final int lapses;
  final CardState state;
  final DateTime? lastReview;
  final DateTime? nextReview;

  FsrsCard copyWith({
    double? stability,
    double? difficulty,
    int? elapsedDays,
    int? scheduledDays,
    int? reps,
    int? lapses,
    CardState? state,
    DateTime? lastReview,
    DateTime? nextReview,
  }) =>
      FsrsCard(
        stability: stability ?? this.stability,
        difficulty: difficulty ?? this.difficulty,
        elapsedDays: elapsedDays ?? this.elapsedDays,
        scheduledDays: scheduledDays ?? this.scheduledDays,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        state: state ?? this.state,
        lastReview: lastReview ?? this.lastReview,
        nextReview: nextReview ?? this.nextReview,
      );

  double get retrievability {
    if (state == CardState.newCard || stability == 0) return 0;
    final t = (DateTime.now().difference(lastReview ?? DateTime.now()).inDays)
        .toDouble();
    return pow(1 + AppFsrs.factor * t / stability, AppFsrs.decay).toDouble();
  }
}

abstract final class AppFsrs {
  static const decay = -0.5;
  static const factor = 19 / 81;
  static const requestRetention = 0.9;
  static const initialDifficulty = 5.0;
  static const initialStability = 1.0;

  static const w = [
    0.4072, 1.1829, 3.1262, 15.4722, 7.2102,
    0.5316, 1.0651, 0.0589, 1.4684, 0.1544,
    1.0070, 1.9395, 0.1100, 0.2900, 2.2700,
    0.1600, 2.9898, 0.5100, 0.4700,
  ];

  static FsrsCard schedule(FsrsCard card, FsrsRating rating, DateTime now) {
    final elapsed = card.lastReview != null
        ? now.difference(card.lastReview!).inDays
        : 0;

    return switch (card.state) {
      CardState.newCard => _scheduleNew(card, rating, now, elapsed),
      CardState.learning => _scheduleLearning(card, rating, now, elapsed),
      CardState.review => _scheduleReview(card, rating, now, elapsed),
      CardState.relearning => _scheduleRelearning(card, rating, now, elapsed),
    };
  }

  static FsrsCard _scheduleNew(
      FsrsCard card, FsrsRating rating, DateTime now, int elapsed) {
    final s = _initStability(rating);
    final d = _initDifficulty(rating);
    final (days, state) = switch (rating) {
      FsrsRating.again => (1, CardState.learning),
      FsrsRating.hard => (1, CardState.learning),
      FsrsRating.good => (1, CardState.learning),
      FsrsRating.easy => (_nextInterval(s), CardState.review),
    };
    return card.copyWith(
      stability: s,
      difficulty: d,
      reps: card.reps + 1,
      state: state,
      scheduledDays: days,
      elapsedDays: elapsed,
      lastReview: now,
      nextReview: now.add(Duration(days: days)),
    );
  }

  static FsrsCard _scheduleLearning(
      FsrsCard card, FsrsRating rating, DateTime now, int elapsed) {
    final s = _shortTermStability(card.stability, rating);
    final d = _nextDifficulty(card.difficulty, rating);
    final (days, state) = switch (rating) {
      FsrsRating.again => (1, CardState.learning),
      FsrsRating.hard => (1, CardState.learning),
      FsrsRating.good => (_nextInterval(s), CardState.review),
      FsrsRating.easy => (_nextInterval(s), CardState.review),
    };
    return card.copyWith(
      stability: s,
      difficulty: d,
      reps: card.reps + 1,
      state: state,
      scheduledDays: days,
      elapsedDays: elapsed,
      lastReview: now,
      nextReview: now.add(Duration(days: days)),
    );
  }

  static FsrsCard _scheduleReview(
      FsrsCard card, FsrsRating rating, DateTime now, int elapsed) {
    final r = card.retrievability;
    final (s, lapses) = switch (rating) {
      FsrsRating.again => (
          _forgetStability(card.difficulty, card.stability, r),
          card.lapses + 1,
        ),
      _ => (
          _recallStability(card.difficulty, card.stability, r, rating),
          card.lapses,
        ),
    };
    final d = _nextDifficulty(card.difficulty, rating);
    final (days, state) = switch (rating) {
      FsrsRating.again => (1, CardState.relearning),
      FsrsRating.hard => (_nextInterval(s), CardState.review),
      FsrsRating.good => (_nextInterval(s), CardState.review),
      FsrsRating.easy => (_nextInterval(s), CardState.review),
    };
    return card.copyWith(
      stability: s,
      difficulty: d,
      reps: card.reps + 1,
      lapses: lapses,
      state: state,
      scheduledDays: days,
      elapsedDays: elapsed,
      lastReview: now,
      nextReview: now.add(Duration(days: days)),
    );
  }

  static FsrsCard _scheduleRelearning(
      FsrsCard card, FsrsRating rating, DateTime now, int elapsed) {
    final s = _shortTermStability(card.stability, rating);
    final d = _nextDifficulty(card.difficulty, rating);
    final (days, state) = switch (rating) {
      FsrsRating.again => (1, CardState.relearning),
      FsrsRating.hard => (1, CardState.relearning),
      FsrsRating.good => (_nextInterval(s), CardState.review),
      FsrsRating.easy => (_nextInterval(s), CardState.review),
    };
    return card.copyWith(
      stability: s,
      difficulty: d,
      reps: card.reps + 1,
      state: state,
      scheduledDays: days,
      elapsedDays: elapsed,
      lastReview: now,
      nextReview: now.add(Duration(days: days)),
    );
  }

  static double _initStability(FsrsRating rating) {
    final idx = rating.index;
    return max(w[idx], 0.1);
  }

  static double _initDifficulty(FsrsRating rating) {
    final d = w[4] - exp(w[5] * (rating.index - 1)) + 1;
    return d.clamp(1.0, 10.0);
  }

  static double _shortTermStability(double s, FsrsRating rating) {
    return s * exp(w[17] * (rating.index - 3 + w[18]));
  }

  static double _recallStability(
      double d, double s, double r, FsrsRating rating) {
    final hardPenalty = rating == FsrsRating.hard ? w[15] : 1;
    final easyBonus = rating == FsrsRating.easy ? w[16] : 1;
    return s *
        (exp(w[8]) *
            (11 - d) *
            pow(s, -w[9]) *
            (exp((1 - r) * w[10]) - 1) *
            hardPenalty *
            easyBonus);
  }

  static double _forgetStability(double d, double s, double r) {
    return w[11] *
        pow(d, -w[12]) *
        (pow(s + 1, w[13]) - 1) *
        exp((1 - r) * w[14]);
  }

  static double _nextDifficulty(double d, FsrsRating rating) {
    final delta = w[6] * (3 - rating.index);
    final next = d - delta + w[7] * (10 - d) / 9;
    return next.clamp(1.0, 10.0);
  }

  static int _nextInterval(double stability) {
    final i =
        (stability / factor * (pow(requestRetention, 1 / decay) - 1)).round();
    return max(i, 1);
  }
}
