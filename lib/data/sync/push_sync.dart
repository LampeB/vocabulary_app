import 'dart:async' show unawaited;
import 'dart:convert' show jsonEncode;
import 'package:drift/drift.dart' show DataClass;

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/daos/concept_dao.dart';
import '../datasources/local/daos/progress_dao.dart';
import '../datasources/local/daos/review_event_dao.dart';
import '../datasources/local/daos/vocabulary_list_dao.dart';
import '../datasources/remote/vocabulary_remote_datasource.dart';
import '../models/concept_dto.dart';
import '../models/variant_progress_dto.dart';
import '../models/vocabulary_list_dto.dart';
import '../models/word_variant_dto.dart';

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
  final _listDrains = <String, Future<_PushRun>>{};
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
      final run = await _pushOnce();
      total += run.pushed;
      if (run.transportUnavailable) break;
    } while (_drainAgain);
    return total;
  }

  Future<_PushRun> _pushOnce() async {
    final run = _PushRun();
    for (final id in await _listDao.getPendingListIds(ownerId: _userId)) {
      final list = await _flushList(id);
      run.pushed += list.pushed;
      if (list.transportUnavailable) {
        run.transportUnavailable = true;
        return run;
      }
    }
    await _drain(
      run,
      rows: () => _progressDao.getUnsyncedProgress(userId: _userId),
      push: (r) => _sendThenAcknowledge(
        _remote.upsertProgress(r.toDomain().toRemoteMap()),
        () => _progressDao.acknowledge(r),
      ),
      onChanged: () => _drainAgain = true,
    );
    await _drain(
      run,
      rows: () => _reviewEventDao.getUnsynced(userId: _userId),
      push: (r) => _sendThenAcknowledge(
          _remote.upsertReviewEvent({
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
            'created_at': r.createdAt.toUtc().toIso8601String(),
          }),
          () => _reviewEventDao.markSynced([r.id])),
    );
    return run;
  }

  /// Flushes the list and its content for publication. A simultaneous global
  /// drain shares work on this list while other lists can progress independently.
  Future<int> pushList(String listId) async =>
      (await _flushList(listId)).pushed;

  Future<_PushRun> _flushList(String listId) {
    if (_userId == '') return Future.value(_PushRun());
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

  Future<_PushRun> _pushListUntilIdle(String listId) async {
    final run = _PushRun();
    void retry() => _listsToRetry.add(listId);

    do {
      _listsToRetry.remove(listId);
      final list = await _listDao.getById(listId);
      if (list == null || (_userId != null && list.ownerId != _userId)) break;

      if (!list.isSynced) {
        await _drain(
          run,
          rows: () async => [list],
          push: (r) => _pushMetadata(
            r,
            id: r.id,
            fromLocalJson: VocabularyListsTableData.fromJson,
            toRemote: (row) => row.toDomain().toRemoteMap(),
            push: _remote.upsertList,
            acknowledge: _listDao.acknowledge,
            load: _listDao.getById,
            save: (row, synced) => _listDao.upsert(row
                .toVocabularyListDomain()
                .copyWith(isSynced: synced)
                .toLocalCompanion()),
            onTombstone: () =>
                _conceptDao.tombstoneListContents(r.id, r.ownerId),
          ),
          onChanged: retry,
        );
      }
      await _drain(
        run,
        rows: () => _conceptDao.getUnsyncedConcepts(listId: listId),
        push: (r) => _pushMetadata(
          r,
          id: r.id,
          fromLocalJson: ConceptsTableData.fromJson,
          toRemote: (row) => row.toRemoteMap(),
          push: _remote.upsertConcept,
          acknowledge: _conceptDao.acknowledgeConcept,
          load: _conceptDao.getById,
          save: (row, synced) => _conceptDao
              .upsert(conceptCompanionFromRemote(row, isSynced: synced)),
          onTombstone: () =>
              _conceptDao.tombstoneConceptContents([r.id], list.ownerId),
        ),
        onChanged: retry,
      );
      await _drain(
        run,
        rows: () => _conceptDao.getUnsyncedVariants(listId: listId),
        push: (r) => _pushMetadata(
          r,
          id: r.id,
          fromLocalJson: WordVariantsTableData.fromJson,
          toRemote: (row) => row.toRemoteMap(),
          push: _remote.upsertVariant,
          acknowledge: _conceptDao.acknowledgeVariant,
          load: _conceptDao.getVariantById,
          save: (row, synced) => _conceptDao.upsertVariant(
              wordVariantCompanionFromRemote(row, isSynced: synced)),
          onTombstone: () => _progressDao.deleteProgressForVariants(
              userId: list.ownerId, variantIds: [r.id]),
          afterAck: (row) {
            if (row['is_deleted'] != true && row['audio_path'] != null) {
              _queueAudio(r.id);
            }
          },
        ),
        onChanged: retry,
      );
    } while (!run.transportUnavailable && _listsToRetry.contains(listId));
    return run;
  }

  Future<Result<int>> _pushMetadata<R extends DataClass>(
    R submitted, {
    required String id,
    required R Function(Map<String, dynamic>) fromLocalJson,
    required Map<String, dynamic> Function(R) toRemote,
    required Future<Result<Map<String, dynamic>>> Function(Map<String, dynamic>,
            {bool insertOnly, Map<String, dynamic>? changes})
        push,
    required Future<int> Function(R) acknowledge,
    required Future<R?> Function(String) load,
    required Future<int> Function(Map<String, dynamic>, bool isSynced) save,
    required Future<void> Function() onTombstone,
    void Function(Map<String, dynamic>)? afterAck,
  }) async {
    final payload = toRemote(submitted);
    final base = await _listDao.getSharedImportBase(id);
    if (base == null) {
      final result = await _sendThenAcknowledge(
          push(payload), () => acknowledge(submitted));
      if (result.valueOrNull == 1) afterAck?.call(payload);
      return result;
    }

    final response = await push(payload,
        insertOnly: true,
        changes: _changedFields(toRemote(fromLocalJson(base)), payload));
    if (response case Failure(:final exception)) return Failure(exception);
    final server = response.valueOrNull!;
    final acknowledgement = await _listDao.transaction(() async {
      final current = await load(id);
      // A pull may have applied a tombstone and cleared this bootstrap while
      // the request was outstanding. Its newer local state owns the row.
      final currentBase = await _listDao.getSharedImportBase(id);
      if (current == null || jsonEncode(base) != jsonEncode(currentBase)) {
        return 0;
      }

      final deleted = server['is_deleted'] == true;
      final remaining = deleted
          ? const <String, dynamic>{}
          : _changedFields(payload, toRemote(current));
      await save(server, true);
      if (deleted) await onTombstone();
      if (remaining.isEmpty) {
        await _listDao.forgetSharedImportBases([id]);
        return 1;
      }

      // Rebase edits made in flight on the acknowledged canonical row. The
      // next pass applies a field patch even when it runs after a restart.
      await _listDao.rememberSharedImport(id, (await load(id))!);
      await save({...server, ...remaining}, false);
      return 0;
    });
    if (acknowledgement == 1) afterAck?.call(server);
    return Success(acknowledgement);
  }

  static Map<String, dynamic> _changedFields(
      Map<String, dynamic> base, Map<String, dynamic> edited) {
    const metadata = {
      'id',
      'owner_id',
      'list_id',
      'concept_id',
      'created_at',
      'updated_at',
      'imported_from_share_token'
    };
    final changes = {
      for (final entry in edited.entries)
        if (!metadata.contains(entry.key) &&
            jsonEncode(base[entry.key]) != jsonEncode(entry.value))
          entry.key: entry.value,
    };
    if (changes.isNotEmpty) changes['updated_at'] = edited['updated_at'];
    return changes;
  }

  Future<Result<int>> _sendThenAcknowledge(
      Future<Result<dynamic>> sent, Future<int> Function() acknowledge) async {
    return switch (await sent) {
      Success() => Success(await acknowledge()),
      Failure(:final exception) => Failure(exception),
    };
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

  Future<void> _drain<R>(
    _PushRun run, {
    required Future<List<R>> Function() rows,
    required Future<Result<int>> Function(R) push,
    void Function()? onChanged,
  }) async {
    if (run.transportUnavailable) return;
    for (final row in await rows()) {
      try {
        final result = await push(row);
        if (result case Success(:final value)) {
          run.pushed++;
          if (value == 0) onChanged?.call();
        } else if (result.exceptionOrNull is NetworkException) {
          run.transportUnavailable = true;
          return;
        }
      } catch (_) {
        // Row stays unsynced; the next drain retries it.
      }
    }
  }
}

class _PushRun {
  int pushed = 0;
  bool transportUnavailable = false;
}
