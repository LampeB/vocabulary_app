// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import '../helpers/fake_remote.dart';

const _kUserId = 'test-user-sync';

Map<String, dynamic> _remoteList(String id, String name) => {
      'id': id,
      'owner_id': _kUserId,
      'name': name,
      'description': null,
      'visibility': 'private',
      'word_count': 1,
      'share_token': null,
      'lang_a': 'en',
      'lang_b': 'es',
      'is_deleted': false,
      'created_at': '2026-07-01T10:00:00Z',
      'updated_at': '2026-07-01T10:00:00Z',
    };

Map<String, dynamic> _remoteConcept(String id, String listId,
        {String fr = 'bonjour', String ko = '안녕'}) =>
    {
      'id': id,
      'list_id': listId,
      'category': null,
      'notes': null,
      'image_url': null,
      'example_fr': null,
      'example_ko': null,
      'is_deleted': false,
      'created_at': '2026-07-01T10:00:00Z',
      'updated_at': '2026-07-01T10:00:00Z',
      'word_variants': [
        {
          'id': '$id-fr',
          'concept_id': id,
          'word': fr,
          'lang_code': 'fr',
          'is_primary': true,
          'position': 0,
          'is_deleted': false,
          'created_at': '2026-07-01T10:00:00Z',
          'updated_at': '2026-07-01T10:00:00Z',
        },
        {
          'id': '$id-ko',
          'concept_id': id,
          'word': ko,
          'lang_code': 'ko',
          'is_primary': true,
          'position': 0,
          'is_deleted': false,
          'created_at': '2026-07-01T10:00:00Z',
          'updated_at': '2026-07-01T10:00:00Z',
        },
      ],
    };

/// Remote with canned lists/concepts, as Supabase would return them.
class _SyncRemote extends FakeRemote {
  _SyncRemote({this.lists = const [], this.conceptsByList = const {}});
  final List<Map<String, dynamic>> lists;
  final Map<String, List<Map<String, dynamic>>> conceptsByList;
  int fetchListsCalls = 0;

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(
      String ownerId) async {
    fetchListsCalls++;
    return Success(lists);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
          String listId) async =>
      Success(conceptsByList[listId] ?? []);
}

void main() {
  late AppDatabase db;

  VocabularyRepositoryImpl repoWith(FakeRemote remote,
          {String userId = _kUserId}) =>
      VocabularyRepositoryImpl(
          db.vocabularyListDao, db.conceptDao, remote, userId, db);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('syncFromRemote', () {
    test('pulls remote lists, concepts and variants into the local DB',
        () async {
      final repo = repoWith(_SyncRemote(
        lists: [_remoteList('rl1', 'Remote List')],
        conceptsByList: {
          'rl1': [_remoteConcept('rc1', 'rl1')],
        },
      ));

      await repo.syncFromRemote();

      final list = await db.vocabularyListDao.getById('rl1');
      expect(list, isNotNull);
      expect(list!.name, 'Remote List');
      expect(list.langA, 'en'); // the pair round-trips through sync
      expect(list.langB, 'es');
      // Word count is recounted from actual local rows, not trusted from the
      // remote payload. (That recount goes through updateWordCount, which by
      // design re-flags the list isSynced=false — so no isSynced assertion.)
      expect(list.wordCount, 1);
      final concepts = await db.conceptDao.getConceptsByList('rl1');
      expect(concepts.length, 1);
      final variants =
          await db.conceptDao.getVariantsByConcept('rc1');
      expect(variants.map((v) => v.word), containsAll(['bonjour', '안녕']));
      expect(variants.every((v) => v.isSynced), isTrue);
    });

    test('does not clobber a local-only (unsynced) list', () async {
      final repo = repoWith(_SyncRemote(
        lists: [_remoteList('rl1', 'Remote List')],
      ));
      final local =
          (await repo.createList(name: 'Local Only')).valueOrNull!;

      await repo.syncFromRemote();

      final still = await db.vocabularyListDao.getById(local.id);
      expect(still, isNotNull);
      expect(still!.name, 'Local Only');
      expect(await db.vocabularyListDao.getById('rl1'), isNotNull);
    });

    test('re-running is idempotent (upserts, no duplicates)', () async {
      final remote = _SyncRemote(
        lists: [_remoteList('rl1', 'Remote List')],
        conceptsByList: {
          'rl1': [_remoteConcept('rc1', 'rl1')],
        },
      );
      final repo = repoWith(remote);

      await repo.syncFromRemote();
      await repo.syncFromRemote();

      final concepts = await db.conceptDao.getConceptsByList('rl1');
      expect(concepts.length, 1);
      final variants = await db.conceptDao.getVariantsByConcept('rc1');
      expect(variants.length, 2);
    });

    test('empty userId skips the remote entirely', () async {
      final remote = _SyncRemote(lists: [_remoteList('rl1', 'X')]);
      final repo = repoWith(remote, userId: '');

      await repo.syncFromRemote();

      expect(remote.fetchListsCalls, 0);
      expect(await db.vocabularyListDao.getById('rl1'), isNull);
    });
  });

  group('getListByShareToken', () {
    test('finds the list once a share link was generated', () async {
      final repo = repoWith(FakeRemote());
      final list = (await repo.createList(name: 'Shared')).valueOrNull!;
      final link = (await repo.generateShareLink(list.id)).valueOrNull!;
      final token = Uri.parse(link).queryParameters['token']!;

      final found = await repo.getListByShareToken(token);

      expect(found.isSuccess, isTrue);
      expect(found.valueOrNull?.id, list.id);
    });

    test('unknown token → Success(null), not an error', () async {
      final repo = repoWith(FakeRemote());
      final found = await repo.getListByShareToken('nope');
      expect(found.isSuccess, isTrue);
      expect(found.valueOrNull, isNull);
    });
  });
}
