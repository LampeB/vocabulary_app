// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
import '../helpers/fake_remote.dart';

/// Outbound sync: the isSynced flags are the queue. Rows written while the
/// backend is down get pushed by the next drain, marked synced, and never
/// pushed again; per-row failures stay queued for the next drain.

/// Records every push; can fail everything or a specific table.
class _RecordingRemote extends FakeRemote {
  bool failAll = false;
  bool failConcepts = false;
  final pushedLists = <Map<String, dynamic>>[];
  final pushedConcepts = <Map<String, dynamic>>[];
  final pushedVariants = <Map<String, dynamic>>[];
  final pushedProgress = <Map<String, dynamic>>[];

  Result<Map<String, dynamic>> _record(
      List<Map<String, dynamic>> sink, Map<String, dynamic> data,
      {bool fail = false}) {
    if (failAll || fail) return const Failure(NetworkException('down'));
    sink.add(data);
    return Success(data);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertList(
          Map<String, dynamic> data) async =>
      _record(pushedLists, data);
  @override
  Future<Result<Map<String, dynamic>>> upsertConcept(
          Map<String, dynamic> data) async =>
      _record(pushedConcepts, data, fail: failConcepts);
  @override
  Future<Result<Map<String, dynamic>>> upsertVariant(
          Map<String, dynamic> data) async =>
      _record(pushedVariants, data);
  @override
  Future<Result<Map<String, dynamic>>> upsertProgress(
          Map<String, dynamic> data) async =>
      _record(pushedProgress, data);
}

void main() {
  late AppDatabase db;
  late _RecordingRemote remote;
  late VocabularyRepositoryImpl repo;
  late PushSync sync;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    remote = _RecordingRemote();
    repo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, remote, 'u', db);
    sync = PushSync(
        db.vocabularyListDao, db.conceptDao, db.progressDao, remote);
  });
  tearDown(() => db.close());

  test('offline writes are drained on the next push: list, concept and both '
      'variants land remotely and are marked synced', () async {
    remote.failAll = true; // backend down while the user works
    final list = (await repo.createList(name: 'Animaux')).valueOrNull!;
    await repo.addConceptWithVariants(
        listId: list.id, frWord: 'chat', koWord: '고양이');
    remote.pushedLists.clear(); // drop the failed fire-and-forget attempts

    remote.failAll = false; // back online
    final pushed = await sync.pushAll();

    expect(pushed, 4); // 1 list + 1 concept + 2 variants
    expect(remote.pushedLists.single['name'], 'Animaux');
    expect(remote.pushedLists.single['lang_a'], 'fr');
    expect(remote.pushedConcepts, hasLength(1));
    expect(remote.pushedVariants.map((v) => v['word']),
        containsAll(['chat', '고양이']));
    expect(await db.vocabularyListDao.getUnsyncedLists(), isEmpty);
    expect(await db.conceptDao.getUnsyncedConcepts(), isEmpty);
    expect(await db.conceptDao.getUnsyncedVariants(), isEmpty);
  });

  test('a second drain pushes nothing (idempotent)', () async {
    await repo.createList(name: 'A');
    await sync.pushAll();
    remote.pushedLists.clear();

    final pushed = await sync.pushAll();

    expect(pushed, 0);
    expect(remote.pushedLists, isEmpty);
  });

  test('a per-table failure keeps ONLY those rows queued; the next drain '
      'retries just them', () async {
    final list = (await repo.createList(name: 'A')).valueOrNull!;
    await repo.addConceptWithVariants(
        listId: list.id, frWord: 'chat', koWord: '고양이');
    remote.failConcepts = true;

    await sync.pushAll();

    // List and variants made it; the concept stayed queued.
    expect(await db.vocabularyListDao.getUnsyncedLists(), isEmpty);
    expect(await db.conceptDao.getUnsyncedConcepts(), hasLength(1));

    remote.failConcepts = false;
    final retried = await sync.pushAll();

    expect(retried, 1); // just the concept
    expect(await db.conceptDao.getUnsyncedConcepts(), isEmpty);
  });

  test('soft-deleted rows are pushed with is_deleted so the delete syncs',
      () async {
    final list = (await repo.createList(name: 'A')).valueOrNull!;
    final concept = (await repo.addConceptWithVariants(
            listId: list.id, frWord: 'chat', koWord: '고양이'))
        .valueOrNull!;
    await sync.pushAll();
    remote.pushedConcepts.clear();

    await repo.deleteConcept(concept.id); // soft-delete → isSynced=false again
    // Let the repo's own fire-and-forget push land, then isolate the drain's.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    remote.pushedConcepts.clear();

    await sync.pushAll();

    expect(remote.pushedConcepts.single['is_deleted'], true);
    expect(await db.conceptDao.getUnsyncedConcepts(), isEmpty);
  });
}
