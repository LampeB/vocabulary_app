import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/remote/vocabulary_remote_datasource.dart';

/// No-op remote stub for integration tests.
/// All write calls succeed; all fetch calls return empty data.
class FakeRemote implements VocabularyRemoteDataSource {
  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(String ownerId) async =>
      const Success([]);

  @override
  Future<Result<Map<String, dynamic>>> upsertList(
          Map<String, dynamic> data) async =>
      Success(data);

  @override
  Future<Result<void>> deleteList(String id) async => const Success(null);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
          String listId) async =>
      const Success([]);

  @override
  Future<Result<Map<String, dynamic>>> upsertConcept(
          Map<String, dynamic> data) async =>
      Success(data);

  @override
  Future<Result<Map<String, dynamic>>> upsertVariant(
          Map<String, dynamic> data) async =>
      Success(data);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchProgress(
          String userId) async =>
      const Success([]);

  @override
  Future<Result<Map<String, dynamic>>> upsertProgress(
          Map<String, dynamic> data) async =>
      Success(data);

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
          String token) async =>
      const Success(null);
}
