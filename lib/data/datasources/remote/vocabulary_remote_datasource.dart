import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../sync/vocabulary_write_order.dart';

typedef ProvisionedAudio = ({String path, String word, String langCode});
typedef VocabularyChangeWindow = ({int after, int through});

/// One elapsed-time budget for a sequence of network calls. A timeout does
/// not prove a submitted write was rejected, so callers must leave it queued.
class VocabularyNetworkBudget {
  VocabularyNetworkBudget(this._total);

  final Duration _total;
  final _elapsed = Stopwatch()..start();
  List<Map<String, dynamic>> _partialRows = const [];
  String? _pageAfter;
  VocabularyChangeWindow? _changes;

  void resumeAfter(String? cursor, {VocabularyChangeWindow? changes}) {
    _pageAfter = cursor;
    _changes = changes;
  }

  List<Map<String, dynamic>> takePartialRows() {
    final rows = _partialRows;
    _partialRows = const [];
    return rows;
  }

  Future<T> _request<T>(
    Future<T> Function() send, {
    Duration? perRequest,
  }) async {
    final remaining = _total - _elapsed.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('Vocabulary network budget expired', _total);
    }
    return send().timeout(
      perRequest != null && perRequest < remaining ? perRequest : remaining,
    );
  }
}

class VocabularyRemoteDataSource {
  VocabularyRemoteDataSource(
    this._client, {
    this._pageTimeout = const Duration(seconds: 15),
    this._writeTimeout = const Duration(seconds: 15),
  });
  final SupabaseClient _client;
  final Duration _pageTimeout;
  final Duration _writeTimeout;

  static const deletedListKey = '_sync_deleted_list';
  static const deletedConceptKey = '_sync_deleted_concept';
  static const pullRevisionKey = '_sync_pull_revision';
  static const _pullPageSize = 500;

  Future<Result<int>> fetchPullRevision(
    String ownerId, {
    required VocabularyNetworkBudget budget,
  }) async {
    try {
      final revision = await budget._request(
        () => _client.rpc<int>(
          'vocabulary_pull_revision',
          params: {'p_owner_id': ownerId},
        ),
      );
      return Success(revision);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<List<Map<String, dynamic>>>> fetchLists(
    String ownerId, {
    VocabularyNetworkBudget? budget,
  }) async {
    try {
      if (budget?._changes case final window?) {
        return Success(await _fetchChanged('lists', ownerId, budget!, window));
      }
      // The initial inventory includes earlier physical purges even when
      // this device has never recorded a server revision.
      return Success(
        await _fetchPages(
          (cursor) => _client
              .rpc<List<Map<String, dynamic>>>(
                'vocabulary_pull_inventory',
                params: {'p_owner_id': ownerId, 'p_after_id': cursor},
              )
              .order('id'),
          budget: budget,
        ),
      );
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<Map<String, dynamic>>> upsertList(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) =>
      _upsertContent('vocabulary_lists', 'owner_id', data, insertOnly, changes);

  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
    String listId, {
    required String ownerId,
    VocabularyNetworkBudget? budget,
  }) async {
    try {
      // Both a full inventory and a changed-list window include physical
      // purges of concepts and their variants.
      return Success(
        await _fetchPages(
          (cursor) => _client
              .rpc<List<Map<String, dynamic>>>(
                'vocabulary_pull_concepts',
                params: {
                  'p_owner_id': ownerId,
                  'p_list_id': listId,
                  'p_after_id': cursor,
                },
              )
              .order('id'),
          budget: budget,
          project: (row) => row['value'] as Map<String, dynamic>,
        ),
      );
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<Map<String, dynamic>>> upsertConcept(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) => _upsertContent('concepts', 'list_id', data, insertOnly, changes);

  Future<Result<Map<String, dynamic>>> upsertVariant(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) =>
      _upsertContent('word_variants', 'concept_id', data, insertOnly, changes);

  Future<Result<Map<String, dynamic>>> _upsertContent(
    String table,
    String parentColumn,
    Map<String, dynamic> data,
    bool insertOnly,
    Map<String, dynamic>? changes,
  ) async {
    final budget = VocabularyNetworkBudget(_writeTimeout);
    try {
      final (stamp, mutation) = VocabularyWriteStamp.take(data);
      final ownerId = data['owner_id'] as String;
      final write = _versionedTable(table, stamp)
          .upsert(
            mutation,
            onConflict: 'owner_id,id',
            ignoreDuplicates: insertOnly,
          )
          .select();
      if (!insertOnly) {
        return Success(
          await _withAncestorTombstones(
            table,
            ownerId,
            await budget._request(write.single),
            budget,
          ),
        );
      }
      final inserted = await budget._request(() => write);
      if (inserted.isNotEmpty) {
        return Success(
          await _withAncestorTombstones(
            table,
            ownerId,
            inserted.single,
            budget,
          ),
        );
      }

      final id = data['id'] as String;
      final parent = data[parentColumn] as String;
      // Even an unchanged copy must consume this sequence under the row lock.
      // An earlier PATCH may still arrive after this acknowledgement.
      // PostgreSQL keeps tombstones immutable and returns the canonical row.
      final existing = await budget._request(
        () => _versionedTable(table, stamp)
            .update({
              ...?changes,
              'sync_write_protocol': mutation['sync_write_protocol'],
            })
            .eq('id', id)
            .eq('owner_id', ownerId)
            .eq(parentColumn, parent)
            .select()
            .single(),
      );
      return Success(
        await _withAncestorTombstones(table, ownerId, existing, budget),
      );
    } on PostgrestException catch (error) {
      // A purge may occur after the insert or before the acknowledgement
      // read. Only a tombstone confirmed by the owner's journal closes the
      // local queue. Unrelated constraint failures remain errors.
      if (const {'PV001', '23503', '23505', 'PGRST116'}.contains(error.code)) {
        try {
          final purged = await budget._request(
            () => _client.rpc<Map<String, dynamic>?>(
              'vocabulary_purge_ack',
              params: {
                'p_owner_id': data['owner_id'],
                'p_kind': switch (table) {
                  'vocabulary_lists' => 'list',
                  'concepts' => 'concept',
                  _ => 'variant',
                },
                'p_id': data['id'],
                'p_parent_id': parentColumn == 'owner_id'
                    ? null
                    : data[parentColumn],
              },
            ),
          );
          if (purged != null) return Success(purged);
        } catch (lookupError) {
          return Failure(_writeFailure(lookupError));
        }
      }
      return Failure(_writeFailure(error));
    } catch (e) {
      return Failure(_writeFailure(e));
    }
  }

  PostgrestQueryBuilder _versionedTable(
    String table,
    VocabularyWriteStamp stamp,
  ) => _client
      .from(table)
      .setHeader('X-Ponderin-Sync-Writer', stamp.writer)
      .setHeader('X-Ponderin-Sync-Sequence', stamp.sequence.toString());

  /// The database write has already enforced tombstones. Read affected
  /// ancestors only in the tombstone case so the device can hide the subtree.
  Future<Map<String, dynamic>> _withAncestorTombstones(
    String table,
    String ownerId,
    Map<String, dynamic> row,
    VocabularyNetworkBudget budget,
  ) async {
    if (row['is_deleted'] != true || table == 'vocabulary_lists') return row;
    if (table == 'concepts') {
      final list = await budget._request(
        () => _client
            .from('vocabulary_lists')
            .select()
            .eq('owner_id', ownerId)
            .eq('id', row['list_id'] as String)
            .single(),
      );
      return list['is_deleted'] == true ? {...row, deletedListKey: list} : row;
    }

    final concept = await budget._request(
      () => _client
          .from('concepts')
          .select('*, vocabulary_lists(*)')
          .eq('owner_id', ownerId)
          .eq('id', row['concept_id'] as String)
          .single(),
    );
    final list = concept.remove('vocabulary_lists') as Map<String, dynamic>?;
    return {
      ...row,
      if (list?['is_deleted'] == true) deletedListKey: list,
      if (concept['is_deleted'] == true) deletedConceptKey: concept,
    };
  }

  AppException _writeFailure(Object error) {
    if (error is SocketException ||
        error is ClientException ||
        error is TimeoutException) {
      return NetworkException(error.toString());
    }
    if (error is PostgrestException &&
        const {
          'PGRST000',
          'PGRST001',
          'PGRST002',
          'PGRST003',
          '502',
          '503',
          '504',
        }.contains(error.code)) {
      return NetworkException(error.toString());
    }
    return StorageException(error.toString());
  }

  /// Asks the authenticated server to render a newly created/edited custom
  /// variant once and place it in Storage. A failed or stale render leaves
  /// device TTS available.
  Future<ProvisionedAudio?> provisionAudio(
    String variantId, {
    required String ownerId,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null || session.user.id != ownerId) return null;
    try {
      final result = await _client.functions
          .invoke(
            'audio-provision',
            body: {'variant_id': variantId},
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 65));
      if (_client.auth.currentUser?.id != ownerId) return null;
      if (result.data
          case {
            'status': 'ready',
            'audio_path': final String path,
            'word': final String word,
            'lang_code': final String langCode,
          }
          when path.startsWith('seed/') ||
              path.startsWith('users/$ownerId/$variantId/')) {
        return (path: path, word: word, langCode: langCode);
      }
    } catch (_) {}
    return null;
  }

  Future<Result<List<Map<String, dynamic>>>> fetchProgress(
    String userId, {
    VocabularyNetworkBudget? budget,
  }) async {
    try {
      if (budget?._changes case final window?) {
        return Success(
          await _fetchChanged('progress', userId, budget!, window),
        );
      }
      return Success(
        await _fetchTablePages(
          () => _client
              .from('variant_progress')
              .select()
              .eq('user_id', userId)
              .eq('variant_owner_id', userId),
          budget: budget,
        ),
      );
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchChanged(
    String kind,
    String ownerId,
    VocabularyNetworkBudget budget,
    VocabularyChangeWindow window,
  ) => _fetchPages(
    (cursor) => _client
        .rpc<List<Map<String, dynamic>>>(
          'vocabulary_pull_changed_$kind',
          params: {
            'p_owner_id': ownerId,
            'p_after': cursor == null ? window.after : int.parse(cursor),
            'p_through': window.through,
          },
        )
        .order('revision'),
    budget: budget,
    cursorColumn: 'revision',
    project: (row) => {
      ...(row['value'] as Map<String, dynamic>),
      pullRevisionKey: row['revision'].toString(),
    },
  );

  Future<List<Map<String, dynamic>>> _fetchTablePages(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> Function() query, {
    VocabularyNetworkBudget? budget,
  }) => _fetchPages((cursor) {
    final filter = query();
    return (cursor == null ? filter : filter.gt('id', cursor))
        .order('id')
        .limit(_pullPageSize);
  }, budget: budget);

  // A capped response cannot prove that a starter or an existing progress
  // identity is absent. Read all pages before reconciling local drafts.
  Future<List<Map<String, dynamic>>> _fetchPages(
    Future<List<Map<String, dynamic>>> Function(String? cursor) fetch, {
    VocabularyNetworkBudget? budget,
    String cursorColumn = 'id',
    Map<String, dynamic> Function(Map<String, dynamic>)? project,
  }) async {
    final rows = <Map<String, dynamic>>[];
    var cursor = budget?._pageAfter;
    final deadline = budget ?? VocabularyNetworkBudget(_pageTimeout);
    try {
      while (true) {
        final page = await deadline._request(
          () => fetch(cursor),
          perRequest: _pageTimeout,
        );
        rows.addAll(project == null ? page : page.map(project));
        if (page.length < _pullPageSize) return rows;
        cursor = page.last[cursorColumn].toString();
      }
    } catch (_) {
      budget?._partialRows = rows;
      rethrow;
    }
  }

  Future<Result<Map<String, dynamic>>> upsertProgress(
    Map<String, dynamic> data,
  ) async {
    try {
      final (stamp, mutation) = VocabularyWriteStamp.take(data);
      final result = await _versionedTable('variant_progress', stamp)
          .upsert({
            ...mutation,
            'variant_owner_id': data['user_id'],
          }, onConflict: 'user_id,variant_owner_id,variant_id,direction')
          .select()
          .single()
          .timeout(_writeTimeout);
      return Success(result);
    } catch (e) {
      return Failure(_writeFailure(e));
    }
  }

  Future<Result<void>> upsertReviewEvent(Map<String, dynamic> data) async {
    try {
      final (stamp, mutation) = VocabularyWriteStamp.take(data);
      await _versionedTable(
        'review_events',
        stamp,
      ).upsert(mutation).timeout(_writeTimeout);
      return const Success(null);
    } catch (e) {
      return Failure(_writeFailure(e));
    }
  }

  Future<Result<Map<String, dynamic>?>> fetchPublicShareMetadata(
    String token,
  ) => _fetchShareMetadata(
    _client
        .from('vocabulary_lists')
        .select()
        .eq('share_token', token)
        .eq('visibility', 'public')
        .eq('is_deleted', false),
  );

  Future<Result<Map<String, dynamic>?>> fetchOwnedListMetadata(
    String ownerId,
    String listId,
  ) => _fetchShareMetadata(
    _client
        .from('vocabulary_lists')
        .select()
        .eq('owner_id', ownerId)
        .eq('id', listId),
  );

  Future<Result<Map<String, dynamic>?>> _fetchShareMetadata(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query,
  ) async {
    try {
      return Success(await query.maybeSingle().timeout(_pageTimeout));
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  // Fetches a public list with its active concepts and variants by share token.
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
    String token,
  ) async {
    try {
      final data = await _client
          .from('vocabulary_lists')
          .select('*, concepts(*, word_variants(*))')
          .eq('share_token', token)
          .eq('visibility', 'public')
          .eq('is_deleted', false)
          .eq('concepts.is_deleted', false)
          .eq('concepts.word_variants.is_deleted', false)
          .maybeSingle()
          .timeout(_pageTimeout);
      return Success(data != null ? Map<String, dynamic>.from(data) : null);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }
}
