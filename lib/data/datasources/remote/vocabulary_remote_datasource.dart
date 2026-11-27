import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';

typedef ProvisionedAudio = ({String path, String word, String langCode});

class VocabularyRemoteDataSource {
  VocabularyRemoteDataSource(
    this._client, {
    this._pageTimeout = const Duration(seconds: 15),
  });
  final SupabaseClient _client;
  final Duration _pageTimeout;

  static const deletedListKey = '_sync_deleted_list';
  static const deletedConceptKey = '_sync_deleted_concept';

  Future<Result<List<Map<String, dynamic>>>> fetchLists(String ownerId) async {
    try {
      // Deleted rows are fetched ON PURPOSE: pull-sync must propagate
      // server-side deletions (tombstones), or a list deleted remotely
      // stays visible on-device forever.
      return Success(
        await _fetchPages(
          () =>
              _client.from('vocabulary_lists').select().eq('owner_id', ownerId),
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

  Future<Result<void>> deleteList(String id) async {
    try {
      await _client
          .from('vocabulary_lists')
          .update({
            'is_deleted': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
    String listId, {
    required String ownerId,
  }) async {
    try {
      // Includes deleted concepts — same tombstone-propagation rationale
      // as fetchLists (the local upsert carries the is_deleted flag).
      return Success(
        await _fetchPages(
          () => _client
              .from('concepts')
              .select('*, word_variants(*)')
              .eq('owner_id', ownerId)
              .eq('list_id', listId),
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
    try {
      final ownerId = data['owner_id'] as String;
      final write = _client
          .from(table)
          .upsert(data, onConflict: 'owner_id,id', ignoreDuplicates: insertOnly)
          .select();
      if (!insertOnly) {
        return Success(
          await _withAncestorTombstones(table, ownerId, await write.single()),
        );
      }
      final inserted = await write;
      if (inserted.isNotEmpty) {
        return Success(
          await _withAncestorTombstones(table, ownerId, inserted.single),
        );
      }

      final id = data['id'] as String;
      final parent = data[parentColumn] as String;
      // Patch only explicit local changes. The live predicate is evaluated
      // by the database alongside the update so a tombstone always wins.
      if (changes != null && changes.isNotEmpty) {
        final updated = await _client
            .from(table)
            .update(changes)
            .eq('id', id)
            .eq('owner_id', ownerId)
            .eq(parentColumn, parent)
            .eq('is_deleted', false)
            .select();
        if (updated.isNotEmpty) {
          return Success(
            await _withAncestorTombstones(table, ownerId, updated.single),
          );
        }
      }
      final existing = await _client
          .from(table)
          .select()
          .eq('id', id)
          .eq('owner_id', ownerId)
          .eq(parentColumn, parent)
          .single();
      return Success(await _withAncestorTombstones(table, ownerId, existing));
    } catch (e) {
      return Failure(_writeFailure(e));
    }
  }

  /// The database write has already enforced tombstones. Read affected
  /// ancestors only in the tombstone case so the device can hide the subtree.
  Future<Map<String, dynamic>> _withAncestorTombstones(
    String table,
    String ownerId,
    Map<String, dynamic> row,
  ) async {
    if (row['is_deleted'] != true || table == 'vocabulary_lists') return row;
    if (table == 'concepts') {
      final list = await _client
          .from('vocabulary_lists')
          .select()
          .eq('owner_id', ownerId)
          .eq('id', row['list_id'] as String)
          .single();
      return list['is_deleted'] == true ? {...row, deletedListKey: list} : row;
    }

    final concept = await _client
        .from('concepts')
        .select('*, vocabulary_lists(*)')
        .eq('owner_id', ownerId)
        .eq('id', row['concept_id'] as String)
        .single();
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
  Future<ProvisionedAudio?> provisionAudio(String variantId) async {
    try {
      final result = await _client.functions.invoke(
        'audio-provision',
        body: {'variant_id': variantId},
      );
      if (result.data case {
        'status': 'ready',
        'audio_path': final String path,
        'word': final String word,
        'lang_code': final String langCode,
      } when path.isNotEmpty) {
        return (path: path, word: word, langCode: langCode);
      }
    } catch (_) {}
    return null;
  }

  Future<Result<List<Map<String, dynamic>>>> fetchProgress(
    String userId,
  ) async {
    try {
      return Success(
        await _fetchPages(
          () => _client
              .from('variant_progress')
              .select()
              .eq('user_id', userId)
              .eq('variant_owner_id', userId),
        ),
      );
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  // A capped response cannot prove that a starter or an existing progress
  // identity is absent. Read all pages before reconciling local drafts.
  Future<List<Map<String, dynamic>>> _fetchPages(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> Function() query,
  ) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    String? lastId;
    while (true) {
      var filter = query();
      if (lastId != null) filter = filter.gt('id', lastId);
      final page = await filter
          .order('id')
          .limit(pageSize)
          .timeout(_pageTimeout);
      rows.addAll(page);
      if (page.length < pageSize) return rows;
      lastId = page.last['id'] as String;
    }
  }

  Future<Result<Map<String, dynamic>>> upsertProgress(
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _client
          .from('variant_progress')
          .upsert({
            ...data,
            'variant_owner_id': data['user_id'],
          }, onConflict: 'user_id,variant_owner_id,variant_id,direction')
          .select()
          .single();
      return Success(result);
    } catch (e) {
      return Failure(_writeFailure(e));
    }
  }

  Future<Result<void>> upsertReviewEvent(Map<String, dynamic> data) async {
    try {
      await _client.from('review_events').upsert(data);
      return const Success(null);
    } catch (e) {
      return Failure(_writeFailure(e));
    }
  }

  // Fetches a public list (with its concepts and variants) by share token.
  // Requires vocabulary_lists to have visibility='public' and a matching RLS policy.
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
          .maybeSingle();
      return Success(data != null ? Map<String, dynamic>.from(data) : null);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }
}
