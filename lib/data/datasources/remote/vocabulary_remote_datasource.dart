import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';

class VocabularyRemoteDataSource {
  VocabularyRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<Result<List<Map<String, dynamic>>>> fetchLists(String ownerId) async {
    try {
      // Deleted rows are fetched ON PURPOSE: pull-sync must propagate
      // server-side deletions (tombstones), or a list deleted remotely
      // stays visible on-device forever.
      final data = await _client
          .from('vocabulary_lists')
          .select()
          .eq('owner_id', ownerId)
          .order('updated_at', ascending: false);
      return Success(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<Map<String, dynamic>>> upsertList(Map<String, dynamic> data,
          {bool insertOnly = false}) =>
      _upsertContent('vocabulary_lists', 'owner_id', data, insertOnly);

  Future<Result<void>> deleteList(String id) async {
    try {
      await _client.from('vocabulary_lists').update({
        'is_deleted': true,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
      String listId) async {
    try {
      // Includes deleted concepts — same tombstone-propagation rationale
      // as fetchLists (the local upsert carries the is_deleted flag).
      final data = await _client
          .from('concepts')
          .select('*, word_variants(*)')
          .eq('list_id', listId)
          .order('created_at');
      return Success(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<Map<String, dynamic>>> upsertConcept(Map<String, dynamic> data,
          {bool insertOnly = false}) =>
      _upsertContent('concepts', 'list_id', data, insertOnly);

  Future<Result<Map<String, dynamic>>> upsertVariant(Map<String, dynamic> data,
          {bool insertOnly = false}) =>
      _upsertContent('word_variants', 'concept_id', data, insertOnly);

  Future<Result<Map<String, dynamic>>> _upsertContent(String table,
      String parentColumn, Map<String, dynamic> data, bool insertOnly) async {
    try {
      final write = _client
          .from(table)
          .upsert(data, ignoreDuplicates: insertOnly)
          .select();
      if (!insertOnly) return Success(await write.single());
      final inserted = await write;
      // An unchanged shared import cannot replace a copy created on another
      // device. Verify the existing row belongs to the same parent before ack.
      final row = inserted.isNotEmpty
          ? inserted.single
          : await _client
              .from(table)
              .select()
              .eq('id', data['id'] as String)
              .eq(parentColumn, data[parentColumn] as String)
              .single();
      return Success(row);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  /// Asks the authenticated server to render a newly created/edited custom
  /// variant once and place it in Storage. Failures are intentionally silent:
  /// sync retries the content, and device TTS remains the safe fallback.
  Future<void> provisionAudio(String variantId) async {
    try {
      await _client.functions.invoke(
        'audio-provision',
        body: {'variant_id': variantId},
      );
    } catch (_) {}
  }

  Future<Result<List<Map<String, dynamic>>>> fetchProgress(
      String userId) async {
    try {
      final data =
          await _client.from('variant_progress').select().eq('user_id', userId);
      return Success(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<Map<String, dynamic>>> upsertProgress(
      Map<String, dynamic> data) async {
    try {
      final result = await _client
          .from('variant_progress')
          .upsert(data, onConflict: 'user_id,variant_id,direction')
          .select()
          .single();
      return Success(result);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<void>> upsertReviewEvent(Map<String, dynamic> data) async {
    try {
      await _client.from('review_events').upsert(data);
      return const Success(null);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  // Fetches a public list (with its concepts and variants) by share token.
  // Requires vocabulary_lists to have visibility='public' and a matching RLS policy.
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
      String token) async {
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
