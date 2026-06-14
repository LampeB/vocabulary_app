import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';

class VocabularyRemoteDataSource {
  VocabularyRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<Result<List<Map<String, dynamic>>>> fetchLists(String ownerId) async {
    try {
      final data = await _client
          .from('vocabulary_lists')
          .select()
          .eq('owner_id', ownerId)
          .eq('is_deleted', false)
          .order('updated_at', ascending: false);
      return Success(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<Map<String, dynamic>>> upsertList(
      Map<String, dynamic> data) async {
    try {
      final result = await _client
          .from('vocabulary_lists')
          .upsert(data)
          .select()
          .single();
      return Success(result);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<void>> deleteList(String id) async {
    try {
      await _client
          .from('vocabulary_lists')
          .update({'is_deleted': true, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      return const Success(null);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
      String listId) async {
    try {
      final data = await _client
          .from('concepts')
          .select('*, word_variants(*)')
          .eq('list_id', listId)
          .eq('is_deleted', false)
          .order('created_at');
      return Success(List<Map<String, dynamic>>.from(data));
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<Map<String, dynamic>>> upsertConcept(
      Map<String, dynamic> data) async {
    try {
      final result =
          await _client.from('concepts').upsert(data).select().single();
      return Success(result);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<Map<String, dynamic>>> upsertVariant(
      Map<String, dynamic> data) async {
    try {
      final result =
          await _client.from('word_variants').upsert(data).select().single();
      return Success(result);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }

  Future<Result<List<Map<String, dynamic>>>> fetchProgress(
      String userId) async {
    try {
      final data = await _client
          .from('variant_progress')
          .select()
          .eq('user_id', userId);
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
          .upsert(data)
          .select()
          .single();
      return Success(result);
    } catch (e) {
      return Failure(NetworkException(e.toString()));
    }
  }
}
