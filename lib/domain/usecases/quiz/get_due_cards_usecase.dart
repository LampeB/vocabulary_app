import '../../repositories/progress_repository.dart';
import '../../entities/variant_progress.dart';
import '../../../core/errors/failure.dart';

/// Where a study session draws its cards from: one list, everything due
/// across lists, everything already started across lists — or a grammar
/// rule (cards are then GENERATED, not fetched; see GrammarDrillGenerator).
enum QuizSource { list, allDue, inProgress, grammar }

class GetDueCardsUseCase {
  const GetDueCardsUseCase(this._repo);
  final ProgressRepository _repo;

  Future<Result<List<VariantProgress>>> call({
    required String userId,
    String? listId,
    QuizSource source = QuizSource.list,
    required QuizDirection direction,
    int limit = 20,
  }) =>
      switch (source) {
        QuizSource.grammar =>
          throw StateError('grammar cards are generated, not fetched'),
        QuizSource.list => _repo.getDueCards(
            userId: userId,
            listId: listId!,
            direction: direction,
            limit: limit,
          ),
        QuizSource.allDue => _repo.getAllDueCards(
            userId: userId,
            direction: direction,
            limit: limit,
          ),
        QuizSource.inProgress => _repo.getInProgressCards(
            userId: userId,
            direction: direction,
            limit: limit,
          ),
      };
}
