import '../../core/errors/failure.dart';
import '../datasources/local/daos/concept_dao.dart';
import '../datasources/local/daos/progress_dao.dart';
import '../datasources/local/daos/vocabulary_list_dao.dart';
import '../datasources/remote/vocabulary_remote_datasource.dart';
import '../models/variant_progress_dto.dart';
import '../models/vocabulary_list_dto.dart';

/// Outbound sync: pushes every row still marked `isSynced=false` to the
/// remote and flips the flag on success.
///
/// The `isSynced` columns ARE the queue (decision on the sync-queue ticket):
/// every local write already sets the flag false, the row itself is the
/// always-fresh payload, and a failed push simply leaves the flag for the
/// next drain — no separate queue table, no stale snapshots, no per-row retry
/// counter (drains are triggered on login and on connectivity regained, so
/// "retry" is a property of the schedule, not the row). Pushes are idempotent
/// remote upserts, so overlapping with the fire-and-forget pushes in the
/// repositories is harmless.
class PushSync {
  PushSync(this._listDao, this._conceptDao, this._progressDao, this._remote);

  final VocabularyListDao _listDao;
  final ConceptDao _conceptDao;
  final ProgressDao _progressDao;
  final VocabularyRemoteDataSource _remote;

  bool _running = false;

  /// Pushes all unsynced rows in FK order (lists → concepts → variants →
  /// progress). Per-row failures are skipped (the row stays unsynced for the
  /// next drain). Returns the number of rows successfully pushed. Re-entrant
  /// calls while a drain is running return 0 immediately.
  Future<int> pushAll() async {
    if (_running) return 0;
    _running = true;
    try {
      var pushed = 0;
      pushed += await _drain(
        rows: await _listDao.getUnsyncedLists(),
        idOf: (r) => r.id,
        push: (r) => _remote.upsertList(r.toDomain().toRemoteMap()),
        markSynced: _listDao.markListsSynced,
      );
      pushed += await _drain(
        rows: await _conceptDao.getUnsyncedConcepts(),
        idOf: (r) => r.id,
        push: (r) => _remote.upsertConcept({
          'id': r.id,
          'list_id': r.listId,
          'category': r.category,
          'notes': r.notes,
          'image_url': r.imageUrl,
          'example_fr': r.exampleFr,
          'example_ko': r.exampleKo,
          'is_deleted': r.isDeleted,
          'created_at': r.createdAt.toIso8601String(),
          'updated_at': r.updatedAt.toIso8601String(),
        }),
        markSynced: _conceptDao.markConceptsSynced,
      );
      pushed += await _drain(
        rows: await _conceptDao.getUnsyncedVariants(),
        idOf: (r) => r.id,
        push: (r) => _remote.upsertVariant({
          'id': r.id,
          'concept_id': r.conceptId,
          'word': r.word,
          'lang_code': r.langCode,
          'register_tag': r.registerTag,
          'is_primary': r.isPrimary,
          'position': r.position,
          'is_deleted': r.isDeleted,
          'created_at': r.createdAt.toIso8601String(),
          'updated_at': r.updatedAt.toIso8601String(),
        }),
        markSynced: _conceptDao.markVariantsSynced,
      );
      pushed += await _drain(
        rows: await _progressDao.getUnsyncedProgress(),
        idOf: (r) => r.id,
        push: (r) => _remote.upsertProgress(r.toDomain().toRemoteMap()),
        markSynced: _progressDao.markProgressSynced,
      );
      return pushed;
    } finally {
      _running = false;
    }
  }

  Future<int> _drain<R>({
    required List<R> rows,
    required String Function(R) idOf,
    required Future<Result<dynamic>> Function(R) push,
    required Future<int> Function(List<String>) markSynced,
  }) async {
    final succeeded = <String>[];
    for (final row in rows) {
      try {
        final result = await push(row);
        if (result.isSuccess) succeeded.add(idOf(row));
      } catch (_) {
        // Row stays unsynced; the next drain retries it.
      }
    }
    if (succeeded.isNotEmpty) await markSynced(succeeded);
    return succeeded.length;
  }
}
