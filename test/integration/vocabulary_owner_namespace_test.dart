import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/remote/vocabulary_remote_datasource.dart';
import 'package:vocab_kr/data/repositories/progress_repository_impl.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';

import '../helpers/fake_remote.dart';

class _ScopedRemote extends FakeRemote {
  final lists = <(String, String), Map<String, dynamic>>{};
  final concepts = <(String, String), Map<String, dynamic>>{};
  final variants = <(String, String), Map<String, dynamic>>{};
  final progress = <(String, String), Map<String, dynamic>>{};
  final events = <Map<String, dynamic>>[];
  final audioRequests = <String>[];

  List<Map<String, dynamic>> _owned(
    Map<(String, String), Map<String, dynamic>> rows,
    String ownerId,
  ) => [
    for (final entry in rows.entries)
      if (entry.key.$1 == ownerId) entry.value,
  ];

  void transferFixture(String ownerId, String fixtureOwnerId) {
    for (final table in [lists, concepts, variants, progress]) {
      for (final row in _owned(table, ownerId)) {
        final id = row['id'] as String;
        table[(fixtureOwnerId, id)] = {
          ...row,
          if (row.containsKey('owner_id')) 'owner_id': fixtureOwnerId,
          if (row.containsKey('user_id')) 'user_id': fixtureOwnerId,
          if (row.containsKey('name'))
            'name': 'Existing account: ${row['name']}',
        };
        table.remove((ownerId, id));
      }
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(String ownerId) async =>
      Success(_owned(lists, ownerId));

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
    String listId, {
    required String ownerId,
  }) async => Success([
    for (final concept in _owned(concepts, ownerId))
      if (concept['list_id'] == listId)
        {
          ...concept,
          'word_variants': _owned(
            variants,
            ownerId,
          ).where((variant) => variant['concept_id'] == concept['id']).toList(),
        },
  ]);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchProgress(
    String userId,
  ) async => Success(_owned(progress, userId));

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
    String token,
  ) async => const Success({
    'name': 'Shared subject',
    'concepts': [
      {
        'id': 'published-concept',
        'word_variants': [
          {'id': 'published-fr', 'word': 'voir', 'lang_code': 'fr'},
          {'id': 'published-ko', 'word': '보다', 'lang_code': 'ko'},
        ],
      },
    ],
  });

  Result<Map<String, dynamic>> _write(
    Map<(String, String), Map<String, dynamic>> table,
    Map<String, dynamic> row, {
    String ownerField = 'owner_id',
  }) {
    table[(row[ownerField] as String, row['id'] as String)] = row;
    return Success(row);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertList(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async => _write(lists, data);

  @override
  Future<Result<Map<String, dynamic>>> upsertConcept(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async => _write(concepts, data);

  @override
  Future<Result<Map<String, dynamic>>> upsertVariant(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async => _write(variants, data);

  @override
  Future<Result<Map<String, dynamic>>> upsertProgress(
    Map<String, dynamic> data,
  ) async => _write(progress, data, ownerField: 'user_id');

  @override
  Future<Result<void>> upsertReviewEvent(Map<String, dynamic> data) async {
    events.add(data);
    return const Success(null);
  }

  @override
  Future<ProvisionedAudio?> provisionAudio(String variantId) async {
    audioRequests.add(variantId);
    return null;
  }
}

const _starter = {
  'list': {
    'name': 'Starter subject',
    'seed_id': 'starter-greetings:fr>ko',
    'concepts': [
      {
        'seed_id': 'bonjour',
        'word_variants': [
          {'word': 'bonjour', 'lang_code': 'fr'},
          {'word': '안녕하세요', 'lang_code': 'ko'},
        ],
      },
    ],
  },
};

void main() {
  test('two accounts with the same server IDs keep their starters, '
      'imports and histories in one SQLite cache', () async {
    final remote = _ScopedRemote();
    final reference = AppDatabase.forTesting(NativeDatabase.memory());
    final shared = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(reference.close);
    addTearDown(shared.close);

    VocabularyRepositoryImpl vocabulary(AppDatabase db, String userId) =>
        VocabularyRepositoryImpl(
          db.vocabularyListDao,
          db.conceptDao,
          remote,
          userId,
          db,
        );
    ProgressRepositoryImpl progressRepo(AppDatabase db, String userId) =>
        ProgressRepositoryImpl(db.progressDao, db.conceptDao, remote, userId);
    PushSync push(AppDatabase db, String userId) => PushSync(
      db.vocabularyListDao,
      db.conceptDao,
      db.progressDao,
      db.reviewEventDao,
      remote,
      userId: userId,
    );
    Future<({String list, String concept, String variant, String progress})>
    answer(AppDatabase db, String listId) async {
      final concept = (await db.conceptDao.getConceptsByList(listId)).single;
      final variant = (await db.conceptDao.getVariantsByConcept(
        concept.id,
      )).singleWhere((row) => row.langCode == 'fr');
      final saved = (await progressRepo(db, 'b').mutateProgress(
        variantId: variant.id,
        direction: QuizDirection.frToKo,
        mutate: (current) =>
            current.copyWith(timesShown: current.timesShown + 1),
      )).valueOrNull!;
      return (
        list: listId,
        concept: concept.id,
        variant: variant.id,
        progress: saved.id,
      );
    }

    final original = vocabulary(reference, 'b');
    await original.syncFromRemote();
    final firstStarter = (await original.importFromJson(
      _starter,
      origin: 'starter',
    )).valueOrNull!;
    final firstShared = (await original.importFromShareToken(
      'published-token',
    )).valueOrNull!;
    final starterKeys = await answer(reference, firstStarter.id);
    final sharedKeys = await answer(reference, firstShared.id);
    await push(reference, 'b').pushAll();
    remote.transferFixture('b', 'a');

    final accountA = vocabulary(shared, 'a');
    await accountA.syncFromRemote();
    final accountB = vocabulary(shared, 'b');
    final secondStarter = (await accountB.importFromJson(
      _starter,
      origin: 'starter',
    )).valueOrNull!;
    final secondShared = (await accountB.importFromShareToken(
      'published-token',
    )).valueOrNull!;
    final starterLocal = await answer(shared, secondStarter.id);
    final sharedLocal = await answer(shared, secondShared.id);
    for (final (local, wire) in [
      (starterLocal, starterKeys),
      (sharedLocal, sharedKeys),
    ]) {
      expect(local.list, isNot(wire.list));
      expect(local.concept, isNot(wire.concept));
      expect(local.variant, isNot(wire.variant));
      expect(local.progress, isNot(wire.progress));
      expect((await shared.progressDao.getById(wire.progress))!.userId, 'a');
      expect((await shared.progressDao.getById(local.progress))!.userId, 'b');
    }
    await shared.reviewEventDao.insertEvent(
      ReviewEventsTableCompanion.insert(
        id: 'collision-review',
        userId: 'b',
        variantId: starterLocal.variant,
        listId: Value(starterLocal.list),
        direction: 'fr>ko',
        mode: 'typing',
        correct: true,
        rating: 'good',
        createdAt: DateTime.utc(2026),
      ),
    );
    await accountB.syncFromRemote();
    remote.audioRequests.clear();
    await push(shared, 'b').pushAll();
    for (final wire in [starterKeys, sharedKeys]) {
      expect(remote.lists[('b', wire.list)]?['id'], wire.list);
      expect(remote.concepts[('b', wire.concept)]?['list_id'], wire.list);
      expect(remote.variants[('b', wire.variant)]?['concept_id'], wire.concept);
      expect(
        remote.progress[('b', wire.progress)]?['variant_id'],
        wire.variant,
      );
      expect(
        remote.lists[('a', wire.list)]?['name'],
        startsWith('Existing account'),
      );
    }
    expect(remote.events.single['variant_id'], starterKeys.variant);
    expect(remote.events.single['list_id'], starterKeys.list);
    expect(
      remote.audioRequests,
      containsAll([starterKeys.variant, sharedKeys.variant]),
    );

    final stored = remote.lists[('b', sharedKeys.list)]!;
    remote.lists[('b', sharedKeys.list)] = {
      ...stored,
      'name': 'Canonical title',
    };
    final reopened = vocabulary(shared, 'b');
    await reopened.syncFromRemote();
    expect(
      (await reopened.getListById(sharedLocal.list)).valueOrNull?.name,
      'Canonical title',
    );
    expect(
      (await accountA.getListById(sharedKeys.list)).valueOrNull?.name,
      startsWith('Existing account'),
    );
    expect(
      (await reopened.importFromShareToken('published-token')).valueOrNull?.id,
      sharedLocal.list,
    );

    remote.lists[('b', sharedKeys.list)] = {...stored, 'is_deleted': true};
    await reopened.syncFromRemote();
    expect((await reopened.getListById(sharedLocal.list)).isFailure, isTrue);
    expect(await shared.progressDao.getById(sharedLocal.progress), isNull);
    expect(await shared.progressDao.getById(sharedKeys.progress), isNotNull);

    final restoredA = vocabulary(reference, 'a');
    await restoredA.syncFromRemote();
    final copiesA = await restoredA.watchMyLists().first;
    final copiesB = await original.watchMyLists().first;
    expect(copiesA, hasLength(2));
    expect(copiesB, hasLength(2));
    expect(
      copiesA.map((list) => list.id).toSet().intersection({
        firstStarter.id,
        firstShared.id,
      }),
      isEmpty,
    );
    expect(
      copiesA.every((list) => list.name.startsWith('Existing account')),
      isTrue,
    );
    expect(copiesB.every((list) => list.ownerId == 'b'), isTrue);
  });
}
