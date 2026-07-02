// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import '../helpers/fake_remote.dart';

const _kUserId = 'test-user-offline';

/// Simulates a dead backend: every write to the remote fails. The repository is
/// local-first (awaits the local DAO, fire-and-forgets the remote), so user
/// actions must still succeed and persist while offline.
class _OfflineRemote extends FakeRemote {
  int writeAttempts = 0;

  Result<T> _fail<T>() {
    writeAttempts++;
    return Failure(NetworkException('offline'));
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertList(
          Map<String, dynamic> data) async =>
      _fail();
  @override
  Future<Result<Map<String, dynamic>>> upsertConcept(
          Map<String, dynamic> data) async =>
      _fail();
  @override
  Future<Result<Map<String, dynamic>>> upsertVariant(
          Map<String, dynamic> data) async =>
      _fail();
  @override
  Future<Result<void>> deleteList(String id) async => _fail();
}

void main() {
  late AppDatabase db;
  late _OfflineRemote remote;
  late VocabularyRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    remote = _OfflineRemote();
    repo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, remote, _kUserId, db);
  });
  tearDown(() => db.close());

  test('creating a list succeeds and persists while the backend is down',
      () async {
    final result = await repo.createList(name: 'Offline List');

    expect(result.isSuccess, isTrue);
    final saved = await db.vocabularyListDao.getById(result.valueOrNull!.id);
    expect(saved, isNotNull);
    expect(saved!.name, 'Offline List');
  });

  test('adding a word succeeds and persists while the backend is down',
      () async {
    final list = (await repo.createList(name: 'Offline List')).valueOrNull!;

    final added = await repo.addConceptWithVariants(
        listId: list.id, frWord: 'bonjour', koWord: '안녕');

    expect(added.isSuccess, isTrue);
    final concepts = await db.conceptDao.getConceptsByList(list.id);
    expect(concepts.length, 1);
    final variants =
        await db.conceptDao.getVariantsByConcept(concepts.first.id);
    expect(variants.map((v) => v.word), containsAll(['bonjour', '안녕']));
  });

  test('the repo actually tried (and swallowed) the failing remote writes',
      () async {
    final list = (await repo.createList(name: 'Offline List')).valueOrNull!;
    await repo.addConceptWithVariants(
        listId: list.id, frWord: 'bonjour', koWord: '안녕');
    // Let the fire-and-forget (unawaited) remote calls run.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // 1 list + 1 concept + 2 variants were all attempted against the remote.
    expect(remote.writeAttempts, greaterThanOrEqualTo(4));
  });
}
