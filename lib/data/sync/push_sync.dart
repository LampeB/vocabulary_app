import 'dart:async' show FutureOr, unawaited;
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
import 'vocabulary_sync_ids.dart';

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
  PushSync(
    this._listDao,
    this._conceptDao,
    this._progressDao,
    this._reviewEventDao,
    this._remote, {
    this._userId,
  });

  final VocabularyListDao _listDao;
  final ConceptDao _conceptDao;
  final ProgressDao _progressDao;
  final ReviewEventDao _reviewEventDao;
  final VocabularyRemoteDataSource _remote;
  final String? _userId;

  Future<int>? _activeDrain;
  bool _drainAgain = false;
  bool _pushRequested = false;
  final _listDrains = <String, Future<_PushRun>>{};
  final _listsToRetry = <String>{};

  static const _maxPendingAudio = 256;
  final _pendingAudio = <(String localId, String wireId, String ownerId)>{};
  bool _provisioningAudio = false;

  /// Pushes all unsynced rows in FK order (lists → concepts → variants →
  /// progress). Per-row failures are skipped (the row stays unsynced for the
  /// next drain). Returns the number of rows successfully pushed. Re-entrant
  /// calls share the current drain and request another pass before completion.
  Future<int> pushAll() {
    if (_userId == '') return Future.value(0);
    if (_activeDrain != null) {
      _pushRequested = true;
      return _activeDrain!;
    }
    return _activeDrain = _pushUntilIdle().whenComplete(
      () => _activeDrain = null,
    );
  }

  Future<int> _pushUntilIdle() async {
    var total = 0;
    do {
      _drainAgain = false;
      _pushRequested = false;
      final run = await _pushOnce();
      total += run.pushed;
      if (run.transportUnavailable && !_pushRequested) break;
    } while (_drainAgain || _pushRequested);
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
    // Read eligible reviews after the network writes above. Draft creation
    // and adoption both change eligibility in the transaction that changes IDs.
    final (progress, events) = await _pendingReviews();
    final idsByOwner = <String, Future<VocabularySyncIds>>{};
    Future<VocabularySyncIds> idsFor(String owner) => idsByOwner.putIfAbsent(
      owner,
      () => VocabularySyncIds.load(_listDao.attachedDatabase, owner),
    );
    await _drain(
      run,
      rows: () async => progress,
      push: (r) async {
        final ids = await idsFor(r.userId);
        return _sendThenAcknowledge(
          _remote.upsertProgress(
            ids.encode(
              SyncedVocabularyRow.progress,
              r.toDomain().toRemoteMap(),
            ),
          ),
          () => _progressDao.acknowledge(r),
        );
      },
      onChanged: () => _drainAgain = true,
    );
    await _drain(
      run,
      rows: () async => events,
      push: (r) async {
        final ids = await idsFor(r.userId);
        final listId = r.listId;
        return _sendThenAcknowledge(
          _remote.upsertReviewEvent({
            'id': r.id,
            'user_id': r.userId,
            'variant_id': ids.wireId(SyncedVocabularyRow.variant, r.variantId),
            'direction': r.direction,
            'list_id': listId == null
                ? null
                : ids.wireId(SyncedVocabularyRow.list, listId),
            'mode': r.mode,
            'correct': r.correct,
            'rating': r.rating,
            'response_time_ms': r.responseTimeMs,
            'retry_count': r.retryCount,
            'created_at': r.createdAt.toUtc().toIso8601String(),
          }),
          () => _reviewEventDao.acknowledge(r),
        );
      },
      onChanged: () => _drainAgain = true,
    );
    return run;
  }

  Future<(List<VariantProgressTableData>, List<ReviewEventsTableData>)>
  _pendingReviews() => _listDao.transaction(() async {
    final heldLists = (await _listDao.heldStarterDrafts(
      ownerId: _userId,
    )).map((list) => list.id).toSet();
    final heldVariants = await _conceptDao.getVariantIdsByLists(heldLists);
    final progress = await _progressDao.getUnsyncedProgress(userId: _userId);
    final events = await _reviewEventDao.getUnsynced(userId: _userId);
    return (
      [
        for (final row in progress)
          if (!heldVariants.contains(row.variantId)) row,
      ],
      [
        for (final row in events)
          if (!heldLists.contains(row.listId) &&
              !heldVariants.contains(row.variantId))
            row,
      ],
    );
  });

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
      if (list.origin == 'starter' &&
          await _listDao.isStarterDraftHeld(listId)) {
        break;
      }
      final ids = await VocabularySyncIds.load(
        _listDao.attachedDatabase,
        list.ownerId,
      );

      if (!list.isSynced) {
        await _drain(
          run,
          rows: () async => [list],
          push: (r) => _pushMetadata(
            r,
            ids: ids,
            kind: SyncedVocabularyRow.list,
            id: r.id,
            fromLocalJson: VocabularyListsTableData.fromJson,
            toRemote: (row) => row.toDomain().toRemoteMap(),
            push: _remote.upsertList,
            acknowledge: _listDao.acknowledge,
            load: _listDao.getById,
            save: (row, synced) => _listDao.upsert(
              row
                  .toVocabularyListDomain()
                  .copyWith(isSynced: synced)
                  .toLocalCompanion(),
            ),
            onTombstone: () =>
                _conceptDao.tombstoneListContents(r.id, r.ownerId),
            afterAck: (_) async {
              if (r.origin == 'starter' && r.seedId != null) {
                await _listDao.transaction(
                  () => _listDao.establishStarterIdentity(r.id),
                );
              }
            },
          ),
          onChanged: retry,
        );
      }
      await _drain(
        run,
        rows: () => _conceptDao.getUnsyncedConcepts(listId: listId),
        push: (r) => _pushMetadata(
          r,
          ids: ids,
          kind: SyncedVocabularyRow.concept,
          id: r.id,
          fromLocalJson: ConceptsTableData.fromJson,
          toRemote: (row) => {...row.toRemoteMap(), 'owner_id': list.ownerId},
          push: _remote.upsertConcept,
          acknowledge: _conceptDao.acknowledgeConcept,
          load: _conceptDao.getById,
          save: (row, synced) => _conceptDao.upsert(
            conceptCompanionFromRemote(row, isSynced: synced),
          ),
          onTombstone: () async {
            await _conceptDao.tombstoneConceptContents([r.id], list.ownerId);
            await _conceptDao.refreshListWordCount(r.listId);
          },
          onAuthoredTombstone: () async {
            await _progressDao.deleteProgressForConcept(
              userId: list.ownerId,
              conceptId: r.id,
            );
            await _conceptDao.refreshListWordCount(r.listId);
          },
        ),
        onChanged: retry,
      );
      await _drain(
        run,
        rows: () => _conceptDao.getUnsyncedVariants(listId: listId),
        push: (r) => _pushMetadata(
          r,
          ids: ids,
          kind: SyncedVocabularyRow.variant,
          id: r.id,
          fromLocalJson: WordVariantsTableData.fromJson,
          toRemote: (row) => {...row.toRemoteMap(), 'owner_id': list.ownerId},
          push: _remote.upsertVariant,
          acknowledge: _conceptDao.acknowledgeVariant,
          load: _conceptDao.getVariantById,
          save: (row, synced) => _conceptDao.upsertVariant(
            wordVariantCompanionFromRemote(row, isSynced: synced),
          ),
          onTombstone: () => _progressDao.deleteProgressForVariants(
            userId: list.ownerId,
            variantIds: [r.id],
          ),
          afterAck: (row) {
            if (row['is_deleted'] != true && row['audio_path'] != null) {
              _queueAudio(
                r.id,
                ids.wireId(SyncedVocabularyRow.variant, r.id),
                list.ownerId,
              );
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
    required VocabularySyncIds ids,
    required SyncedVocabularyRow kind,
    required String id,
    required R Function(Map<String, dynamic>) fromLocalJson,
    required Map<String, dynamic> Function(R) toRemote,
    required Future<Result<Map<String, dynamic>>> Function(
      Map<String, dynamic>, {
      bool insertOnly,
      Map<String, dynamic>? changes,
    })
    push,
    required Future<int> Function(R) acknowledge,
    required Future<R?> Function(String) load,
    required Future<int> Function(Map<String, dynamic>, bool isSynced) save,
    required Future<void> Function() onTombstone,
    Future<void> Function()? onAuthoredTombstone,
    FutureOr<void> Function(Map<String, dynamic>)? afterAck,
  }) async {
    Map<String, dynamic> wire(R row) => ids.encode(kind, toRemote(row));
    final payload = wire(submitted);
    final base = await _listDao.getSharedImportBase(id);
    final response = base == null
        ? await push(payload)
        : await push(
            payload,
            insertOnly: true,
            changes: _changedFields(wire(fromLocalJson(base)), payload),
          );
    if (response case Failure(:final exception)) return Failure(exception);
    final server = ids.decode(kind, response.valueOrNull!);
    final deleted = server['is_deleted'] == true;
    final ancestorDeleted =
        server.containsKey(VocabularyRemoteDataSource.deletedListKey) ||
        server.containsKey(VocabularyRemoteDataSource.deletedConceptKey);
    if (deleted &&
        (base != null || payload['is_deleted'] != true || ancestorDeleted)) {
      return Success(
        await _listDao.transaction(() async {
          if (await load(id) == null) return 0;
          await save(server, true);
          if (ancestorDeleted) {
            await _applyAncestorTombstone(server);
          } else {
            await onTombstone();
          }
          await _listDao.forgetSharedImportBases([id]);
          return 1;
        }),
      );
    }
    if (base == null) {
      final value = deleted && onAuthoredTombstone != null
          ? await _listDao.transaction(() async {
              final acknowledged = await acknowledge(submitted);
              if (acknowledged == 1) await onAuthoredTombstone();
              return acknowledged;
            })
          : await acknowledge(submitted);
      if (value == 1 && !deleted) await afterAck?.call(server);
      return Success(value);
    }

    final acknowledgement = await _listDao.transaction(() async {
      final current = await load(id);
      // A pull may have applied a tombstone and cleared this bootstrap while
      // the request was outstanding. Its newer local state owns the row.
      final currentBase = await _listDao.getSharedImportBase(id);
      if (current == null || jsonEncode(base) != jsonEncode(currentBase)) {
        return 0;
      }

      final remaining = _changedFields(payload, wire(current));
      await save(server, true);
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
    if (acknowledgement == 1) await afterAck?.call(server);
    return Success(acknowledgement);
  }

  Future<void> _applyAncestorTombstone(Map<String, dynamic> response) async {
    final listRow =
        response[VocabularyRemoteDataSource.deletedListKey]
            as Map<String, dynamic>?;
    if (listRow != null) {
      final list = listRow.toVocabularyListDomain();
      await _listDao.upsert(list.toLocalCompanion());
      await _listDao.forgetSharedImportBases([list.id]);
      await _conceptDao.tombstoneListContents(list.id, list.ownerId);
      return;
    }

    final conceptRow =
        response[VocabularyRemoteDataSource.deletedConceptKey]
            as Map<String, dynamic>;
    final concept = conceptCompanionFromRemote(conceptRow);
    final list = await _listDao.getById(concept.listId.value);
    if (list == null) return;
    await _conceptDao.upsert(concept);
    await _listDao.forgetSharedImportBases([concept.id.value]);
    await _conceptDao.tombstoneConceptContents([
      concept.id.value,
    ], list.ownerId);
    await _conceptDao.refreshListWordCount(list.id);
  }

  static Map<String, dynamic> _changedFields(
    Map<String, dynamic> base,
    Map<String, dynamic> edited,
  ) {
    const metadata = {
      'id',
      'owner_id',
      'list_id',
      'concept_id',
      'created_at',
      'updated_at',
      'imported_from_share_token',
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
    Future<Result<dynamic>> sent,
    Future<int> Function() acknowledge,
  ) async {
    return switch (await sent) {
      Success() => Success(await acknowledge()),
      Failure(:final exception) => Failure(exception),
    };
  }

  void _queueAudio(String localId, String wireId, String ownerId) {
    if (_pendingAudio.length >= _maxPendingAudio) return;
    _pendingAudio.add((localId, wireId, ownerId));
    if (!_provisioningAudio) unawaited(_provisionAudio());
  }

  Future<void> _provisionAudio() async {
    _provisioningAudio = true;
    while (_pendingAudio.isNotEmpty) {
      final request = _pendingAudio.first;
      _pendingAudio.remove(request);
      final (localId, wireId, ownerId) = request;
      try {
        final audio = await _remote.provisionAudio(wireId, ownerId: ownerId);
        if (audio != null) {
          await _conceptDao.applyProvisionedAudio(
            variantId: localId,
            ownerId: ownerId,
            word: audio.word,
            langCode: audio.langCode,
            path: audio.path,
          );
        }
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
