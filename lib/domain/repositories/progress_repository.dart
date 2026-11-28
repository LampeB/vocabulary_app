import '../entities/variant_progress.dart'; // also exports kMasteryThresholdDays
import '../../core/errors/failure.dart';

abstract interface class ProgressRepository {
  Future<Result<List<VariantProgress>>> getDueCards({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
    bool includeScheduled = false,
  });

  /// Cross-list due cards — the "À réviser maintenant" smart list. Only
  /// already-started cards scheduled at or before now (new words are not due).
  Future<Result<List<VariantProgress>>> getAllDueCards({
    required String userId,
    required QuizDirection direction,
    String? langA,
    String? langB,
    int limit = 20,
  });

  /// Cross-list started cards (FSRS state ≠ new), due or not — the
  /// "En cours d'apprentissage" smart list.
  Future<Result<List<VariantProgress>>> getInProgressCards({
    required String userId,
    required QuizDirection direction,
    String? langA,
    String? langB,
    int limit = 20,
  });

  Future<Result<VariantProgress>> getProgress({
    required String variantId,
    required QuizDirection direction,
  });

  Future<Result<VariantProgress>> updateProgress(VariantProgress progress);

  /// Applies [mutate] to the current card for this account in one transaction.
  Future<Result<VariantProgress>> mutateProgress({
    required String variantId,
    required QuizDirection direction,
    required VariantProgress Function(VariantProgress) mutate,
  });

  Future<Result<Map<String, int>>> getListStats(String listId);

  Future<Result<void>> resetProgress(String listId);

  Stream<int> watchDueCount(String userId);

  /// Returns all progress entries the user has mastered (FSRS review state,
  /// scheduled ≥ [kMasteryThresholdDays] days) — the long-retention bar
  /// shown in stats.
  Future<Result<List<VariantProgress>>> getMasteredVariants(String userId);
}
