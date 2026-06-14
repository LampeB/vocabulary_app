import '../../repositories/progress_repository.dart';
import '../../entities/variant_progress.dart';
import '../../../core/errors/failure.dart';

class GetDueCardsUseCase {
  const GetDueCardsUseCase(this._repo);
  final ProgressRepository _repo;

  Future<Result<List<VariantProgress>>> call({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
  }) =>
      _repo.getDueCards(
        userId: userId,
        listId: listId,
        direction: direction,
        limit: limit,
      );
}
