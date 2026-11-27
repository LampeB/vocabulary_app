// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/models/concept_dto.dart';
import 'package:vocab_kr/data/models/variant_progress_dto.dart';
import 'package:vocab_kr/data/models/vocabulary_list_dto.dart';
import 'package:vocab_kr/data/models/word_variant_dto.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/seed/starter_seeder.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import '../helpers/fake_remote.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/presentation/providers/settings/default_pair_provider.dart';

class _HistoricalStarterRemote extends FakeRemote {
  bool offline = true;
  final lists = <Map<String, dynamic>>[];
  final concepts = <Map<String, dynamic>>[];
  final progress = <Map<String, dynamic>>[];
  final pushedLists = <Map<String, dynamic>>[];
  final pushedProgress = <Map<String, dynamic>>[];
  final pushedEvents = <Map<String, dynamic>>[];

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchLists(String ownerId) async =>
      offline ? const Failure(NetworkException('offline')) : Success(lists);

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchConcepts(
    String listId,
  ) async =>
      Success(concepts.where((row) => row['list_id'] == listId).toList());

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchProgress(
    String userId,
  ) async => Success(progress);

  @override
  Future<Result<Map<String, dynamic>>> upsertList(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async {
    pushedLists.add(data);
    return Success(data);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertProgress(
    Map<String, dynamic> data,
  ) async {
    pushedProgress.add(data);
    return Success(data);
  }

  @override
  Future<Result<void>> upsertReviewEvent(Map<String, dynamic> data) async {
    pushedEvents.add(data);
    return const Success(null);
  }
}

class _FailOnceSeedRepository extends VocabularyRepositoryImpl {
  _FailOnceSeedRepository(AppDatabase db)
    : super(db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u1', db);
  bool fail = true;
  @override
  Future<Result<VocabularyList>> importFromJson(
    Map<String, dynamic> json, {
    String origin = 'user',
  }) {
    if (fail) {
      fail = false;
      return Future.value(
        const Failure(StorageException('temporary disk failure')),
      );
    }
    return super.importFromJson(json, origin: origin);
  }
}

/// Pair-aware starter seeding from the catalog (assets/seed/vocab/ — the REAL
/// assets, so this also validates the shipped content): composing fr>ko must
/// reproduce the canonical 6 lists / 111 concepts, dedup by seed_id, adopt
/// lists created by the old name-keyed pipeline, and heal installs whose
/// concepts lost every variant to the pre-v3 import bug.

AppUser _user(String id) => AppUser(
  id: id,
  email: 't@t.fr',
  username: 'thomas',
  subscriptionType: SubscriptionType.free,
  createdAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // rootBundle for the assets

  late AppDatabase db;
  late VocabularyRepositoryImpl repo;

  ProviderContainer makeContainer({String userId = 'u1'}) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vocabularyRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(_user(userId)),
        syncOnLoginProvider.overrideWith((ref) async {}),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> seed({String source = 'fr', String target = 'ko'}) =>
      makeContainer()
          .read(starterSeederProvider)
          .ensureSeededForPair(source, target);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      FakeRemote(),
      'u1',
      db,
    );
  });
  tearDown(() => db.close());

  for (final conflictingHistory in [false, true]) {
    test(
      'offline seed finds the historical server identity${conflictingHistory ? ' and preserves conflicting histories' : ''}',
      () async {
        final remote = _HistoricalStarterRemote();
        repo = VocabularyRepositoryImpl(
          db.vocabularyListDao,
          db.conceptDao,
          remote,
          'u1',
          db,
        );
        final push = PushSync(
          db.vocabularyListDao,
          db.conceptDao,
          db.progressDao,
          db.reviewEventDao,
          remote,
          userId: 'u1',
        );
        await expectLater(
          repo.syncFromRemote(),
          throwsA(isA<NetworkException>()),
        );
        await seed();
        final draft = (await repo.watchMyLists().first).firstWhere(
          (row) => row.seedId == 'starter-greetings:fr>ko',
        );
        final concept = (await db.conceptDao.getConceptsByList(draft.id)).first;
        final words = await db.conceptDao.getVariantsByConcept(concept.id);
        final fr = words.firstWhere((word) => word.langCode == 'fr');
        final ko = words.firstWhere((word) => word.langCode == 'ko');
        final now = DateTime.utc(2026, 11, 27);
        final localProgress = VariantProgress(
          id: 'draft-progress',
          userId: 'u1',
          variantId: fr.id,
          direction: QuizDirection.frToKo,
          reps: 2,
          timesShown: 2,
          createdAt: now,
          updatedAt: now,
        );
        await db.progressDao.upsertLocal(localProgress.toLocalCompanion());
        await db.reviewEventDao.insertEvent(
          ReviewEventsTableCompanion.insert(
            id: 'draft-review-event',
            userId: 'u1',
            variantId: fr.id,
            listId: Value(draft.id),
            direction: 'fr>ko',
            mode: 'typing',
            correct: true,
            rating: 'good',
            createdAt: now,
          ),
        );

        // The write endpoint can be available while the restore endpoint fails.
        // An unresolved starter never leaks into that drain, including its FK rows.
        final personal = (await repo.createList(name: 'Personal')).valueOrNull!;
        expect(await push.pushAll(), 1);
        expect(remote.pushedLists.map((row) => row['id']), [personal.id]);
        expect(remote.pushedProgress, isEmpty);
        expect(remote.pushedEvents, isEmpty);

        const oldList = 'legacy-random-list';
        const oldConcept = 'legacy-random-concept';
        const oldFr = 'legacy-random-fr';
        const oldKo = 'legacy-random-ko';
        remote.lists.add({
          ...draft.toRemoteMap(),
          'id': oldList,
          'name': 'Edited on first device',
        });
        remote.concepts.add({
          ...concept.toRemoteMap(),
          'id': oldConcept,
          'list_id': oldList,
          'notes': 'Existing note',
          'word_variants': [
            {
              ...fr.toRemoteMap(),
              'id': oldFr,
              'concept_id': oldConcept,
              'word': 'Edited existing word',
            },
            {...ko.toRemoteMap(), 'id': oldKo, 'concept_id': oldConcept},
          ],
        });
        final oldProgress = localProgress.copyWith(
          id: 'server-progress',
          variantId: conflictingHistory ? oldFr : oldKo,
          direction: conflictingHistory
              ? QuizDirection.frToKo
              : QuizDirection.koToFr,
          reps: 12,
          timesShown: 12,
        );
        remote.progress.add(oldProgress.toRemoteMap());
        remote.offline = false;

        await repo.syncFromRemote();
        final copies = (await repo.watchMyLists().first)
            .where((row) => row.seedId == draft.seedId)
            .toList();
        expect(
          copies.where((row) => row.id == oldList).single.name,
          'Edited on first device',
        );
        expect(
          (await db.conceptDao.getVariantById(oldFr))!.word,
          'Edited existing word',
        );
        expect((await db.progressDao.getById(oldProgress.id))!.reps, 12);
        final saved = (await db.progressDao.getById(localProgress.id))!;
        if (conflictingHistory) {
          expect(
            copies.map((row) => row.id),
            unorderedEquals([draft.id, oldList]),
          );
          expect(saved.variantId, fr.id);
          expect(
            await db.vocabularyListDao.isStarterDraftHeld(draft.id),
            isTrue,
          );
        } else {
          expect(copies.single.id, oldList);
          expect(saved.variantId, oldFr);
          expect(
            (await db.reviewEventDao.getByUser('u1')).single.variantId,
            oldFr,
          );
        }
        await push.pushAll();
        expect(
          remote.pushedLists.where((row) => row['seed_id'] == draft.seedId),
          isEmpty,
        );
        expect(
          remote.pushedProgress.any((row) => row['variant_id'] == fr.id),
          isFalse,
        );
        expect(
          remote.pushedEvents.any((row) => row['variant_id'] == fr.id),
          isFalse,
        );
      },
    );
  }

  test('a held starter keeps divergent local FSRS off the shared ID', () async {
    final remote = _HistoricalStarterRemote()..offline = false;
    final otherDevice = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(otherDevice.close);
    VocabularyRepositoryImpl repository(AppDatabase device) =>
        VocabularyRepositoryImpl(
          device.vocabularyListDao,
          device.conceptDao,
          remote,
          'u1',
          device,
        );
    final otherRepo = repository(otherDevice);
    repo = repository(db);
    const starter = {
      'list': {
        'name': 'Greetings',
        'seedId': 'starter-greetings:fr>ko',
        'concepts': [
          {
            'seedId': 'hello',
            'variants': [
              {'word': 'Bonjour', 'langCode': 'fr'},
              {'word': '안녕하세요', 'langCode': 'ko'},
            ],
          },
        ],
      },
    };
    await otherRepo.syncFromRemote();
    final established = (await otherRepo.importFromJson(
      starter,
      origin: 'starter',
    )).valueOrNull!;
    final establishedConcept = (await otherDevice.conceptDao.getConceptsByList(
      established.id,
    )).single;
    final variants = await otherDevice.conceptDao.getVariantsByConcept(
      establishedConcept.id,
    );
    final variant = variants.singleWhere((word) => word.langCode == 'fr');
    final now = DateTime.utc(2026, 11, 27);
    final serverProgress = VariantProgress(
      id: 'same-progress-id',
      userId: 'u1',
      variantId: variant.id,
      direction: QuizDirection.frToKo,
      reps: 12,
      timesShown: 12,
      timesCorrect: 10,
      createdAt: now,
      updatedAt: now,
    );
    await otherDevice.progressDao.upsertLocal(
      serverProgress.toLocalCompanion(),
    );
    remote.lists.add(established.toRemoteMap());
    remote.concepts.add({
      ...establishedConcept.toRemoteMap(),
      'word_variants': variants.map((word) => word.toRemoteMap()).toList(),
    });
    remote.progress.add(serverProgress.toRemoteMap());

    remote.offline = true;
    await expectLater(repo.syncFromRemote(), throwsA(isA<NetworkException>()));
    final draft = (await repo.importFromJson(
      starter,
      origin: 'starter',
    )).valueOrNull!;
    final localConcept = (await db.conceptDao.getConceptsByList(
      draft.id,
    )).single;
    final localVariant = (await db.conceptDao.getVariantsByConcept(
      localConcept.id,
    )).singleWhere((word) => word.langCode == 'fr');
    expect(draft.id, established.id);
    expect(localConcept.id, establishedConcept.id);
    expect(localVariant.id, variant.id);
    final localProgress = serverProgress.copyWith(
      reps: 2,
      timesShown: 2,
      timesCorrect: 1,
    );
    await db.progressDao.upsertLocal(localProgress.toLocalCompanion());
    remote.offline = false;

    await repo.syncFromRemote();
    expect(await db.vocabularyListDao.isStarterDraftHeld(draft.id), isTrue);
    final localRow = (await db.progressDao.getById(localProgress.id))!;
    expect(localRow.reps, 2);
    expect(localRow.isSynced, isFalse);
    final push = PushSync(
      db.vocabularyListDao,
      db.conceptDao,
      db.progressDao,
      db.reviewEventDao,
      remote,
      userId: 'u1',
    );
    expect(await push.pushAll(), 0);
    expect(remote.pushedProgress, isEmpty);
    expect(remote.progress.single['reps'], 12);
    expect(
      (await otherDevice.progressDao.getById(serverProgress.id))?.reps,
      12,
    );
  });

  test(
    'a brand-new user gets the 6 fr>ko starter lists with all their words',
    () async {
      await seed();

      final lists = await repo.watchMyLists().first;
      expect(lists.length, 6);
      expect(lists.map((l) => l.name), contains('Les particules essentielles'));
      expect(
        lists.every((l) => l.origin == 'starter'),
        isTrue,
        reason: 'seeded lists must be quota-exempt',
      );
      expect(lists.every((l) => l.langA == 'fr' && l.langB == 'ko'), isTrue);
      expect(
        lists.every((l) => l.seedId?.endsWith(':fr>ko') ?? false),
        isTrue,
        reason: 'catalog lists must carry their stable seed identity',
      );

      var totalConcepts = 0;
      var examplesSeen = 0;
      for (final l in lists) {
        final concepts = await db.conceptDao.getConceptsByList(l.id);
        totalConcepts += concepts.length;
        for (final concept in concepts) {
          expect(concept.seedId, isNotNull);
          final variants = await db.conceptDao.getVariantsByConcept(concept.id);
          final langs = variants.map((v) => v.langCode).toSet();
          expect(
            langs.containsAll({'fr', 'ko'}),
            isTrue,
            reason:
                'concept ${concept.seedId} in "${l.name}" must have a '
                'word in both languages, got $langs',
          );
          examplesSeen += variants.where((v) => v.example != null).length;
          expect(
            variants.every(
              (v) => v.audioPath?.startsWith('seed/v1/${v.langCode}/') ?? false,
            ),
            isTrue,
            reason: 'starter content must reference shared pre-rendered audio',
          );
        }
      }
      expect(totalConcepts, 111);
      // 55 of the 111 concepts ship an example pair today (the complete
      // starter-greetings list included); every one survives in both languages.
      expect(
        examplesSeen,
        110,
        reason: 'per-variant example sentences must survive composition',
      );
    },
  );

  test('French list names come from the seed.list.* translations', () async {
    await seed();
    final names = (await repo.watchMyLists().first).map((l) => l.name).toSet();
    expect(
      names,
      containsAll({
        'Salutations & politesse',
        'Les nombres & le temps',
        'La nourriture',
        'La vie quotidienne',
        'Se déplacer',
        'Les particules essentielles',
      }),
      reason:
          'canonical French names must be stable (E2E + legacy adoption '
          'both key on them)',
    );
  });

  test('seeding is once-ever per pair: a second run adds nothing', () async {
    await seed();
    await seed();
    expect((await repo.watchMyLists().first).length, 6);
  });

  test(
    'concurrent seed calls share a single complete catalogue import',
    () async {
      await Future.wait(List.generate(4, (_) => seed()));
      final lists = await repo.watchMyLists().first;
      expect(lists, hasLength(6));
      expect(lists.map((list) => list.seedId).toSet(), hasLength(6));
    },
  );

  test(
    'an import failure does not mark the pair complete and retry heals it',
    () async {
      repo = _FailOnceSeedRepository(db);
      await expectLater(seed(), throwsStateError);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool(StarterSeeder.flagKeyFor('u1', 'fr', 'ko')),
        isNot(true),
      );
      await seed();
      expect(await repo.watchMyLists().first, hasLength(6));
      expect(
        preferences.getBool(StarterSeeder.flagKeyFor('u1', 'fr', 'ko')),
        isTrue,
      );
    },
  );

  test(
    'a user with pre-existing lists still receives the starter lists',
    () async {
      await repo.createList(name: 'Ma liste');
      await seed();

      final lists = await repo.watchMyLists().first;
      expect(lists.length, 7); // their own list + the 6 starter lists
      expect(lists.where((l) => l.origin == 'starter').length, 6);
    },
  );

  test('legacy adoption: a healthy pre-catalog starter list is stamped, not '
      'duplicated, and its concepts keep their variant rows', () async {
    // Simulate a list seeded by the old name-keyed pipeline: canonical name,
    // origin starter, no seed_id, one healthy concept.
    final created = await repo.importFromJson({
      'list': {
        'name': 'Salutations & politesse',
        'lang_a': 'fr',
        'lang_b': 'ko',
        'concepts': [
          {
            'category': 'expression',
            'word_variants': [
              {'word': 'bonjour', 'lang_code': 'fr', 'is_primary': true},
              {'word': '안녕하세요', 'lang_code': 'ko', 'is_primary': true},
            ],
          },
        ],
      },
    }, origin: 'starter');
    final legacyListId = (created as dynamic).value.id as String;
    final legacyConcept = (await db.conceptDao.getConceptsByList(
      legacyListId,
    )).single;
    final legacyVariantIds = (await db.conceptDao.getVariantsByConcept(
      legacyConcept.id,
    )).map((v) => v.id).toSet();

    await seed();

    final lists = await repo.watchMyLists().first;
    expect(lists.length, 6, reason: 'adopted, not re-imported');
    final adopted = lists.singleWhere((l) => l.id == legacyListId);
    expect(adopted.seedId, 'starter-greetings:fr>ko');

    final concepts = await db.conceptDao.getConceptsByList(legacyListId);
    expect(concepts.length, 18, reason: 'topped up to the full curriculum');
    final bonjour = concepts.singleWhere((c) => c.seedId == 'bonjour');
    expect(
      bonjour.id,
      legacyConcept.id,
      reason: 'the healthy legacy concept was recognized by word match',
    );
    final variantIdsNow = (await db.conceptDao.getVariantsByConcept(
      bonjour.id,
    )).map((v) => v.id).toSet();
    expect(
      variantIdsNow,
      legacyVariantIds,
      reason:
          'existing variant rows (which may carry FSRS progress) must '
          'never be replaced',
    );
  });

  test('healing: a list whose concepts lost every variant to the pre-v3 import '
      'bug is rebuilt with full content', () async {
    // A broken install: concepts exist but the snake_case mismatch dropped
    // all variants (and therefore all examples and quiz cards).
    final created = await repo.importFromJson({
      'list': {
        'name': 'La nourriture',
        'lang_a': 'fr',
        'lang_b': 'ko',
        'concepts': [
          {'category': 'nom', 'notes': 'orphaned'},
          {'category': 'nom', 'notes': 'orphaned too'},
        ],
      },
    }, origin: 'starter');
    final brokenListId = (created as dynamic).value.id as String;

    await seed();

    final concepts = await db.conceptDao.getConceptsByList(brokenListId);
    expect(concepts.length, 18, reason: 'orphans removed, curriculum seeded');
    expect(concepts.every((c) => c.seedId != null), isTrue);
    for (final c in concepts) {
      expect(
        (await db.conceptDao.getVariantsByConcept(c.id)).length,
        greaterThanOrEqualTo(2),
      );
    }
  });

  test(
    'en>de seeds the 5 universal lists — no Korean particles list',
    () async {
      await seed(source: 'en', target: 'de');

      final lists = await repo.watchMyLists().first;
      expect(
        lists.length,
        5,
        reason: 'the ko-scoped particles list must not seed for de',
      );
      expect(lists.every((l) => l.langA == 'en' && l.langB == 'de'), isTrue);
      expect(
        lists.map((l) => l.name),
        contains('Numbers & time'),
        reason: 'names resolve UI locale → source language; both are en here',
      );
      for (final l in lists) {
        final concepts = await db.conceptDao.getConceptsByList(l.id);
        for (final c in concepts) {
          final langs = (await db.conceptDao.getVariantsByConcept(
            c.id,
          )).map((v) => v.langCode).toSet();
          expect(langs.containsAll({'en', 'de'}), isTrue);
        }
      }
    },
  );

  test('both directions of a pair are distinct curricula', () async {
    await seed(source: 'fr', target: 'ko');
    await seed(source: 'ko', target: 'fr');

    final lists = await repo.watchMyLists().first;
    // fr>ko has the particles list (target ko), ko>fr does not.
    expect(lists.where((l) => l.seedId?.endsWith(':fr>ko') ?? false).length, 6);
    expect(lists.where((l) => l.seedId?.endsWith(':ko>fr') ?? false).length, 5);
  });

  test(
    'an unknown language layer seeds nothing and does NOT set the flag',
    () async {
      await seed(source: 'fr', target: 'xx');
      expect(await repo.watchMyLists().first, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(StarterSeeder.flagKeyFor('u1', 'fr', 'xx')),
        isNull,
        reason: 'a later release shipping the layer must still seed',
      );
    },
  );

  test('deleting everything later does NOT re-seed (flag is sticky)', () async {
    await seed();
    for (final l in await repo.watchMyLists().first) {
      await repo.deleteList(l.id);
    }
    await seed();
    expect(await repo.watchMyLists().first, isEmpty);
  });

  test(
    'the seedStarterListsProvider seeds the persisted default pair',
    () async {
      SharedPreferences.setMockInitialValues({
        'settings_default_lang_a': 'fr',
        'settings_default_lang_b': 'ko',
      });
      final c = makeContainer();
      // Keep an active listener like the home screen's ref.watch does —
      // defaultPairProvider's async prefs load invalidates the seed provider
      // mid-flight, and a bare .future read would never see the recompute.
      c.listen(seedStarterListsProvider, (_, _) {});
      await c.read(seedStarterListsProvider.future);
      expect((await repo.watchMyLists().first).length, 6);
    },
  );

  test(
    'the authenticated bootstrap follows an unseeded pair selection',
    () async {
      SharedPreferences.setMockInitialValues({
        'settings_default_lang_a': 'fr',
        'settings_default_lang_b': 'ko',
      });
      final container = makeContainer();
      final active = container.listen(seedStarterListsProvider, (_, _) {});
      addTearDown(active.close);
      await container.read(seedStarterListsProvider.future);
      expect(
        (await repo.watchMyLists().first)
            .map((row) => (row.langA, row.langB))
            .toSet(),
        {('fr', 'ko')},
      );

      final selected = container
          .read(defaultPairProvider.notifier)
          .set('ko', 'fr');
      await container.read(seedStarterListsProvider.future);
      await selected;
      final lists = await repo.watchMyLists().first;
      expect(
        lists.where((row) => (row.langA, row.langB) == ('fr', 'ko')),
        hasLength(6),
      );
      expect(
        lists.where((row) => (row.langA, row.langB) == ('ko', 'fr')),
        hasLength(5),
      );
    },
  );
}
