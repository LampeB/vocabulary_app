import '../../repositories/progress_repository.dart';
import '../../entities/variant_progress.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/fsrs_algorithm.dart';

class SubmitAnswerUseCase {
  const SubmitAnswerUseCase(this._repo);
  final ProgressRepository _repo;

  Future<Result<VariantProgress>> call({
    required VariantProgress progress,
    required FsrsRating rating,
  }) {
    final now = DateTime.now();
    final card = FsrsCard(
      stability: progress.stability,
      difficulty: progress.difficulty,
      elapsedDays: progress.elapsedDays,
      scheduledDays: progress.scheduledDays,
      reps: progress.reps,
      lapses: progress.lapses,
      state: progress.state,
      lastReview: progress.lastReview,
      nextReview: progress.nextReview,
    );

    final updated = AppFsrs.schedule(card, rating, now);
    final isCorrect = rating != FsrsRating.again;

    final newProgress = progress.copyWith(
      stability: updated.stability,
      difficulty: updated.difficulty,
      elapsedDays: updated.elapsedDays,
      scheduledDays: updated.scheduledDays,
      reps: updated.reps,
      lapses: updated.lapses,
      state: updated.state,
      lastReview: updated.lastReview,
      nextReview: updated.nextReview,
      timesShown: progress.timesShown + 1,
      timesCorrect: progress.timesCorrect + (isCorrect ? 1 : 0),
      masteryLevel: progress.reps > 0
          ? (progress.timesCorrect + (isCorrect ? 1 : 0)) /
              (progress.timesShown + 1)
          : 0,
      isSynced: false,
      updatedAt: now,
    );

    return _repo.updateProgress(newProgress);
  }
}
