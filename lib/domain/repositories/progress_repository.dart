import '../entities/variant_progress.dart';
import '../../core/errors/failure.dart';

abstract interface class ProgressRepository {
  Future<Result<List<VariantProgress>>> getDueCards({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
  });

  Future<Result<VariantProgress>> getProgress({
    required String variantId,
    required QuizDirection direction,
  });

  Future<Result<VariantProgress>> updateProgress(VariantProgress progress);

  Future<Result<Map<String, int>>> getListStats(String listId);

  Future<Result<void>> resetProgress(String listId);

  Stream<int> watchDueCount(String userId);
}
