import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/utils/fsrs_algorithm.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/repositories/progress_repository.dart';
import 'package:vocab_kr/domain/usecases/quiz/submit_answer_usecase.dart';

// ---------------------------------------------------------------------------
// Minimal fake — captures the progress passed to updateProgress.
// ---------------------------------------------------------------------------
class _FakeProgressRepo implements ProgressRepository {
  VariantProgress? captured;

  @override
  Future<Result<VariantProgress>> updateProgress(VariantProgress progress) async {
    captured = progress;
    return Success(progress);
  }

  // ── unused stubs ──────────────────────────────────────────────────────────
  @override Future<Result<List<VariantProgress>>> getDueCards({required String userId, required String listId, required QuizDirection direction, int limit = 20}) async => throw UnimplementedError();
  @override Future<Result<VariantProgress>> getProgress({required String variantId, required QuizDirection direction}) async => throw UnimplementedError();
  @override Future<Result<Map<String, int>>> getListStats(String listId) async => throw UnimplementedError();
  @override Future<Result<void>> resetProgress(String listId) async => throw UnimplementedError();
  @override Stream<int> watchDueCount(String userId) => throw UnimplementedError();
  @override Future<Result<List<VariantProgress>>> getMasteredVariants(String userId) async => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Helper — build a VariantProgress at a known state.
// ---------------------------------------------------------------------------
VariantProgress _makeProgress({
  int reps = 0,
  int timesShown = 0,
  int timesCorrect = 0,
  CardState state = CardState.newCard,
  int lapses = 0,
  double stability = 0,
}) {
  final now = DateTime(2025);
  return VariantProgress(
    id: 'p-1',
    userId: 'u-1',
    variantId: 'v-1',
    direction: QuizDirection.frToKo,
    reps: reps,
    timesShown: timesShown,
    timesCorrect: timesCorrect,
    state: state,
    lapses: lapses,
    stability: stability,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late _FakeProgressRepo fakeRepo;
  late SubmitAnswerUseCase useCase;

  setUp(() {
    fakeRepo = _FakeProgressRepo();
    useCase = SubmitAnswerUseCase(fakeRepo);
  });

  group('timesShown counter', () {
    for (final rating in FsrsRating.values) {
      test('increments by 1 for ${rating.name}', () async {
        await useCase.call(progress: _makeProgress(timesShown: 3), rating: rating);
        expect(fakeRepo.captured!.timesShown, 4);
      });
    }

    test('starts at 0 and becomes 1 after first answer', () async {
      await useCase.call(progress: _makeProgress(), rating: FsrsRating.good);
      expect(fakeRepo.captured!.timesShown, 1);
    });
  });

  group('timesCorrect counter', () {
    test('Again does NOT increment timesCorrect', () async {
      await useCase.call(
          progress: _makeProgress(timesCorrect: 2), rating: FsrsRating.again);
      expect(fakeRepo.captured!.timesCorrect, 2);
    });

    test('Hard increments timesCorrect', () async {
      await useCase.call(
          progress: _makeProgress(timesCorrect: 2), rating: FsrsRating.hard);
      expect(fakeRepo.captured!.timesCorrect, 3);
    });

    test('Good increments timesCorrect', () async {
      await useCase.call(
          progress: _makeProgress(timesCorrect: 2), rating: FsrsRating.good);
      expect(fakeRepo.captured!.timesCorrect, 3);
    });

    test('Easy increments timesCorrect', () async {
      await useCase.call(
          progress: _makeProgress(timesCorrect: 2), rating: FsrsRating.easy);
      expect(fakeRepo.captured!.timesCorrect, 3);
    });
  });

  group('masteryLevel', () {
    test('is 0.0 when reps == 0 (new card), regardless of rating', () async {
      await useCase.call(progress: _makeProgress(reps: 0), rating: FsrsRating.good);
      expect(fakeRepo.captured!.masteryLevel, 0.0);
    });

    test('calculated when reps > 0 and answer is correct', () async {
      // timesCorrect=4, timesShown=4, reps=3 → after correct: (4+1)/(4+1) = 1.0
      await useCase.call(
        progress: _makeProgress(reps: 3, timesShown: 4, timesCorrect: 4),
        rating: FsrsRating.good,
      );
      expect(fakeRepo.captured!.masteryLevel, closeTo(1.0, 0.001));
    });

    test('calculated when reps > 0 and answer is wrong', () async {
      // timesCorrect=2, timesShown=4, reps=3 → after wrong: 2/(4+1) = 0.4
      await useCase.call(
        progress: _makeProgress(reps: 3, timesShown: 4, timesCorrect: 2),
        rating: FsrsRating.again,
      );
      expect(fakeRepo.captured!.masteryLevel, closeTo(0.4, 0.001));
    });
  });

  group('FSRS fields are delegated to AppFsrs.schedule', () {
    test('new card + Good → state changes to learning', () async {
      await useCase.call(progress: _makeProgress(), rating: FsrsRating.good);
      expect(fakeRepo.captured!.state, CardState.learning);
    });

    test('new card + Good → reps increments to 1', () async {
      await useCase.call(progress: _makeProgress(), rating: FsrsRating.good);
      expect(fakeRepo.captured!.reps, 1);
    });
  });

  group('isSynced', () {
    test('is always false after submission', () async {
      final progress = _makeProgress().copyWith(isSynced: true);
      await useCase.call(progress: progress, rating: FsrsRating.good);
      expect(fakeRepo.captured!.isSynced, isFalse);
    });
  });
}
