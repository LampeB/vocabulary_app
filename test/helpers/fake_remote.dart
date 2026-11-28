import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/remote/vocabulary_remote_datasource.dart';

/// No-op remote stub for integration tests.
/// All write calls succeed; all fetch calls return empty data.
class FakeRemote implements VocabularyRemoteDataSource {
  @override
  Future<ProvisionedAudio?> provisionAudio(
    String variantId, {
    required String ownerId,
  }) async => null;
  @override
  Future<Result<int>> fetchPullRevision(
    String ownerId, {
    required VocabularyNetworkBudget budget,
  }) async => const Success(0);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(
    String ownerId, {
    VocabularyNetworkBudget? budget,
  }) async => const Success([]);

  @override
  Future<Result<Map<String, dynamic>>> upsertList(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async => Success(data);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
    String listId, {
    required String ownerId,
    VocabularyNetworkBudget? budget,
  }) async => const Success([]);

  @override
  Future<Result<Map<String, dynamic>>> upsertConcept(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async => Success(data);

  @override
  Future<Result<Map<String, dynamic>>> upsertVariant(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async => Success(data);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchProgress(
    String userId, {
    VocabularyNetworkBudget? budget,
  }) async => const Success([]);

  @override
  Future<Result<Map<String, dynamic>>> upsertProgress(
    Map<String, dynamic> data,
  ) async => Success(data);

  @override
  Future<Result<void>> upsertReviewEvent(Map<String, dynamic> data) async =>
      const Success(null);

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicShareMetadata(
    String token,
  ) => fetchPublicListByToken(token);

  @override
  Future<Result<Map<String, dynamic>?>> fetchOwnedListMetadata(
    String ownerId,
    String listId,
  ) async {
    final result = await fetchLists(ownerId);
    return result.fold(
      onSuccess: (rows) =>
          Success(rows.where((row) => row['id'] == listId).firstOrNull),
      onFailure: Failure.new,
    );
  }

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
    String token,
  ) async => const Success(null);
}
