import 'dart:async' show unawaited;
import 'package:uuid/uuid.dart';
import '../../domain/entities/variant_progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../core/errors/failure.dart';
import '../../core/errors/app_exception.dart';
import '../datasources/local/daos/progress_dao.dart';
import '../datasources/local/daos/concept_dao.dart';
import '../datasources/remote/vocabulary_remote_datasource.dart';
import '../models/variant_progress_dto.dart';

const _uuid = Uuid();

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl(
    this._progressDao,
    this._conceptDao,
    this._remote,
    this._userId,
  );

  final ProgressDao _progressDao;
  final ConceptDao _conceptDao;
  final VocabularyRemoteDataSource _remote;
  final String _userId;

  @override
  Future<Result<List<VariantProgress>>> getDueCards({
    required String userId,
    required String listId,
    required QuizDirection direction,
    int limit = 20,
  }) async {
    try {
      final questionLang = direction == QuizDirection.frToKo ? 'fr' : 'ko';

      final concepts = await _conceptDao.getConceptsByList(listId);
      if (concepts.isEmpty) return const Success([]);

      final conceptIds = concepts.map((c) => c.id).toList();
      final questionVariants = await _conceptDao.getVariantsByConceptIds(
          conceptIds, questionLang);
      if (questionVariants.isEmpty) return const Success([]);

      final allVariantIds = questionVariants.map((v) => v.id).toList();

      // Existing due/learning cards
      final dueRows = await _progressDao.getDue(
        userId: userId,
        direction: direction.name,
        variantIds: allVariantIds,
        limit: limit,
      );
      final existingVariantIds = dueRows.map((r) => r.variantId).toSet();

      // New cards (no progress row yet): fill up to limit
      final newVariantIds = allVariantIds
          .where((id) => !existingVariantIds.contains(id))
          .take(limit - dueRows.length)
          .toList();

      final now = DateTime.now();
      final dueCards = dueRows.map((r) => r.toDomain()).toList();
      final newCards = newVariantIds
          .map((variantId) => VariantProgress(
                id: _uuid.v4(),
                userId: userId,
                variantId: variantId,
                direction: direction,
                createdAt: now,
                updatedAt: now,
              ))
          .toList();

      return Success([...dueCards, ...newCards].take(limit).toList());
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<VariantProgress>> getProgress({
    required String variantId,
    required QuizDirection direction,
  }) async {
    try {
      final row = await _progressDao.getByVariantAndDirection(
          variantId, direction.name);
      if (row == null) {
        final now = DateTime.now();
        return Success(VariantProgress(
          id: _uuid.v4(),
          userId: _userId,
          variantId: variantId,
          direction: direction,
          createdAt: now,
          updatedAt: now,
        ));
      }
      return Success(row.toDomain());
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<VariantProgress>> updateProgress(VariantProgress progress) async {
    try {
      await _progressDao.upsert(progress.toLocalCompanion());
      unawaited(_remote.upsertProgress(progress.toRemoteMap()));
      return Success(progress);
    } catch (e) {
      return Failure(StorageException(e.toString()));
    }
  }

  @override
  Future<Result<Map<String, int>>> getListStats(String listId) async {
    return const Success({'total': 0, 'mastered': 0, 'due': 0});
  }

  @override
  Future<Result<void>> resetProgress(String listId) async {
    return const Success(null);
  }

  @override
  Stream<int> watchDueCount(String userId) =>
      _progressDao.watchDueCount(userId);
}
