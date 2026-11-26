import 'dart:convert' show jsonDecode;
import '../../core/errors/failure.dart';
import '../datasources/local/daos/concept_dao.dart';
import '../datasources/local/daos/progress_dao.dart';
import '../datasources/local/daos/review_event_dao.dart';
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
/// "retry" is a property of the schedule, not the row). This is the sole
/// remote writer for local mutations, so an unsynced row cannot be clobbered
/// by a competing fire-and-forget repository write.
class PushSync {
  PushSync(this._listDao, this._conceptDao, this._progressDao,
      this._reviewEventDao, this._remote,
      {String? userId})
      : _userId = userId;

  final VocabularyListDao _listDao;
  final ConceptDao _conceptDao;
  final ProgressDao _progressDao;
  final ReviewEventDao _reviewEventDao;
  final VocabularyRemoteDataSource _remote;
  final String? _userId;

  bool _running = false;
  Future<int>? _activeDrain;
  bool _drainAgain = false;

  /// Pushes all unsynced rows in FK order (lists → concepts → variants →
  /// progress). Per-row failures are skipped (the row stays unsynced for the
  /// next drain). Returns the number of rows successfully pushed. Re-entrant
  /// calls share the current drain and request another pass before completion.
  Future<int> pushAll() {
    if (_userId == '') return Future.value(0);
    if (_activeDrain != null) {
      _drainAgain = true;
      return _activeDrain!;
    }
    final drain = _pushUntilIdle();
    _activeDrain = drain;
    return drain.whenComplete(() => _activeDrain = null);
  }

  Future<int> _pushUntilIdle() async {
    var total = 0;
    do {
      _drainAgain = false;
      total += await _pushOnce();
    } while (_drainAgain);
    return total;
  }

  Future<int> _pushOnce() async {
    if (_running) return 0;
    _running = true;
    try {
      var pushed = 0;
      pushed += await _drain(
        rows: await _listDao.getUnsyncedLists(ownerId: _userId),
        idOf: (r) => r.id,
        push: (r) => _remote.upsertList(r.toDomain().toRemoteMap()),
        markSynced: _listDao.acknowledge,
      );
      pushed += await _drain(
        rows: await _conceptDao.getUnsyncedConcepts(ownerId: _userId),
        idOf: (r) => r.id,
        push: (r) => _remote.upsertConcept({
          'id': r.id,
          'list_id': r.listId,
          'category': r.category,
          'notes': r.notes,
          'image_url': r.imageUrl,
          'example_fr': r.exampleFr,
          'example_ko': r.exampleKo,
          'seed_id': r.seedId,
          'is_deleted': r.isDeleted,
          'created_at': r.createdAt.toIso8601String(),
          'updated_at': r.updatedAt.toIso8601String(),
        }),
        markSynced: _conceptDao.acknowledgeConcept,
      );
      pushed += await _drain(
        rows: await _conceptDao.getUnsyncedVariants(ownerId: _userId),
        idOf: (r) => r.id,
        push: (r) => _remote.upsertVariant({
          'id': r.id,
          'concept_id': r.conceptId,
          'word': r.word,
          'lang_code': r.langCode,
          'register_tag': r.registerTag,
          'context_tags': jsonDecode(r.contextTags),
          'is_primary': r.isPrimary,
          'audio_hash': r.audioHash,
          'audio_voice_id': r.audioVoiceId,
          'audio_path': r.audioPath,
          'position': r.position,
          'example': r.example,
          'is_deleted': r.isDeleted,
          'created_at': r.createdAt.toIso8601String(),
          'updated_at': r.updatedAt.toIso8601String(),
        }),
        markSynced: _conceptDao.acknowledgeVariant,
        afterSuccess: (row) async {
          // Audio is provisioned only after the durable variant upsert. A
          // best-effort failure must not re-send the variant payload itself.
          if (!row.isDeleted && row.audioPath != null) {
            try {
              await _remote.provisionAudio(row.id);
            } catch (_) {}
          }
        },
      );
      pushed += await _drain(
        rows: await _progressDao.getUnsyncedProgress(userId: _userId),
        idOf: (r) => r.id,
        push: (r) => _remote.upsertProgress(r.toDomain().toRemoteMap()),
        markSynced: _progressDao.acknowledge,
      );
      pushed += await _drain(
        rows: await _reviewEventDao.getUnsynced(userId: _userId),
        idOf: (r) => r.id,
        push: (r) => _remote.upsertReviewEvent({
          'id': r.id,
          'user_id': r.userId,
          'variant_id': r.variantId,
          'direction': r.direction,
          'list_id': r.listId,
          'mode': r.mode,
          'correct': r.correct,
          'rating': r.rating,
          'response_time_ms': r.responseTimeMs,
          'retry_count': r.retryCount,
          'created_at': r.createdAt.toIso8601String(),
        }),
        markSynced: (r) => _reviewEventDao.markSynced([r.id]),
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
    required Future<int> Function(R) markSynced,
    Future<void> Function(R row)? afterSuccess,
  }) async {
    final succeeded = <String>[];
    for (final row in rows) {
      try {
        final result = await push(row);
        if (result.isSuccess) {
          succeeded.add(idOf(row));
          final acknowledged = await markSynced(row);
          if (acknowledged == 0) _drainAgain = true;
          if (afterSuccess != null) await afterSuccess(row);
        }
      } catch (_) {
        // Row stays unsynced; the next drain retries it.
      }
    }
    return succeeded.length;
  }
}
