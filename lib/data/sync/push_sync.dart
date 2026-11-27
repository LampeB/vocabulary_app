import 'dart:async' show unawaited;
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

  Future<int>? _activeDrain;
  bool _drainAgain = false;
  final _listDrains = <String, Future<int>>{};
  final _listsToRetry = <String>{};

  static const _maxPendingAudio = 256;
  final _pendingAudio = <String>{};
  bool _provisioningAudio = false;

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
    var pushed = 0;
    for (final id in await _listDao.getPendingListIds(ownerId: _userId)) {
      pushed += await pushList(id);
    }
    pushed += await _drain(
      rows: await _progressDao.getUnsyncedProgress(userId: _userId),
      push: (r) => _remote.upsertProgress(r.toDomain().toRemoteMap()),
      markSynced: _progressDao.acknowledge,
      onChanged: () => _drainAgain = true,
    );
    pushed += await _drain(
      rows: await _reviewEventDao.getUnsynced(userId: _userId),
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
  }

  /// Flushes the list and its content for publication. A simultaneous global
  /// drain shares work on this list while other lists can progress independently.
  Future<int> pushList(String listId) {
    if (_userId == '') return Future.value(0);
    final active = _listDrains[listId];
    if (active != null) {
      _listsToRetry.add(listId);
      return active;
    }
    final drain = _pushListUntilIdle(listId).whenComplete(() {
      _listDrains.remove(listId);
      _listsToRetry.remove(listId);
    });
    _listDrains[listId] = drain;
    return drain;
  }

  Future<int> _pushListUntilIdle(String listId) async {
    var pushed = 0;
    void retry() => _listsToRetry.add(listId);

    do {
      _listsToRetry.remove(listId);
      final list = await _listDao.getById(listId);
      if (list == null || (_userId != null && list.ownerId != _userId)) break;

      if (!list.isSynced) {
        pushed += await _drain(
          rows: [list],
          push: (r) async => _remote.upsertList(r.toDomain().toRemoteMap(),
              insertOnly: await _listDao.isInitialSharedImport(r.id, r)),
          markSynced: (r) =>
              _listDao.acknowledgeMetadata(r.id, () => _listDao.acknowledge(r)),
          onChanged: retry,
        );
      }
      pushed += await _drain(
        rows: await _conceptDao.getUnsyncedConcepts(listId: listId),
        push: (r) async => _remote.upsertConcept({
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
        }, insertOnly: await _listDao.isInitialSharedImport(r.id, r)),
        markSynced: (r) => _listDao.acknowledgeMetadata(
            r.id, () => _conceptDao.acknowledgeConcept(r)),
        onChanged: retry,
      );
      pushed += await _drain(
        rows: await _conceptDao.getUnsyncedVariants(listId: listId),
        push: (r) async => _remote.upsertVariant({
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
        }, insertOnly: await _listDao.isInitialSharedImport(r.id, r)),
        markSynced: (r) => _listDao.acknowledgeMetadata(
            r.id, () => _conceptDao.acknowledgeVariant(r)),
        onChanged: retry,
        afterAck: (row) {
          if (!row.isDeleted && row.audioPath != null) {
            _queueAudio(row.id);
          }
        },
      );
    } while (_listsToRetry.contains(listId));
    return pushed;
  }

  void _queueAudio(String variantId) {
    if (_pendingAudio.length >= _maxPendingAudio) return;
    _pendingAudio.add(variantId);
    if (!_provisioningAudio) unawaited(_provisionAudio());
  }

  Future<void> _provisionAudio() async {
    _provisioningAudio = true;
    while (_pendingAudio.isNotEmpty) {
      final id = _pendingAudio.first;
      _pendingAudio.remove(id);
      try {
        await _remote.provisionAudio(id);
      } catch (_) {
        // The durable metadata has already landed. Device TTS is available.
      }
    }
    _provisioningAudio = false;
  }

  Future<int> _drain<R>({
    required List<R> rows,
    required Future<Result<dynamic>> Function(R) push,
    required Future<int> Function(R) markSynced,
    void Function()? onChanged,
    void Function(R row)? afterAck,
  }) async {
    var succeeded = 0;
    for (final row in rows) {
      try {
        final result = await push(row);
        if (result.isSuccess) {
          succeeded++;
          final acknowledged = await markSynced(row);
          if (acknowledged == 0) {
            onChanged?.call();
          } else {
            afterAck?.call(row);
          }
        }
      } catch (_) {
        // Row stays unsynced; the next drain retries it.
      }
    }
    return succeeded;
  }
}
