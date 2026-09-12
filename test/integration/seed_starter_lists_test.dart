// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/seed/starter_seeder.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import '../helpers/fake_remote.dart';

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
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      vocabularyRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(_user(userId)),
      syncOnLoginProvider.overrideWith((ref) async {}),
    ]);
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
        db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u1', db);
  });
  tearDown(() => db.close());

  test('a brand-new user gets the 6 fr>ko starter lists with all their words',
      () async {
    await seed();

    final lists = await repo.watchMyLists().first;
    expect(lists.length, 6);
    expect(lists.map((l) => l.name), contains('Les particules essentielles'));
    expect(lists.every((l) => l.origin == 'starter'), isTrue,
        reason: 'seeded lists must be quota-exempt');
    expect(lists.every((l) => l.langA == 'fr' && l.langB == 'ko'), isTrue);
    expect(lists.every((l) => l.seedId?.endsWith(':fr>ko') ?? false), isTrue,
        reason: 'catalog lists must carry their stable seed identity');

    var totalConcepts = 0;
    var examplesSeen = 0;
    for (final l in lists) {
      final concepts = await db.conceptDao.getConceptsByList(l.id);
      totalConcepts += concepts.length;
      for (final concept in concepts) {
        expect(concept.seedId, isNotNull);
        final variants = await db.conceptDao.getVariantsByConcept(concept.id);
        final langs = variants.map((v) => v.langCode).toSet();
        expect(langs.containsAll({'fr', 'ko'}), isTrue,
            reason: 'concept ${concept.seedId} in "${l.name}" must have a '
                'word in both languages, got $langs');
        examplesSeen += variants.where((v) => v.example != null).length;
      }
    }
    expect(totalConcepts, 111);
    // 55 of the 111 concepts ship an example pair today (the complete
    // starter-greetings list included); every one survives in both languages.
    expect(examplesSeen, 110,
        reason: 'per-variant example sentences must survive composition');
  });

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
        reason: 'canonical French names must be stable (E2E + legacy adoption '
            'both key on them)');
  });

  test('seeding is once-ever per pair: a second run adds nothing', () async {
    await seed();
    await seed();
    expect((await repo.watchMyLists().first).length, 6);
  });

  test('a user with pre-existing lists still receives the starter lists',
      () async {
    await repo.createList(name: 'Ma liste');
    await seed();

    final lists = await repo.watchMyLists().first;
    expect(lists.length, 7); // their own list + the 6 starter lists
    expect(lists.where((l) => l.origin == 'starter').length, 6);
  });

  test(
      'legacy adoption: a healthy pre-catalog starter list is stamped, not '
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
    final legacyConcept =
        (await db.conceptDao.getConceptsByList(legacyListId)).single;
    final legacyVariantIds =
        (await db.conceptDao.getVariantsByConcept(legacyConcept.id))
            .map((v) => v.id)
            .toSet();

    await seed();

    final lists = await repo.watchMyLists().first;
    expect(lists.length, 6, reason: 'adopted, not re-imported');
    final adopted = lists.singleWhere((l) => l.id == legacyListId);
    expect(adopted.seedId, 'starter-greetings:fr>ko');

    final concepts = await db.conceptDao.getConceptsByList(legacyListId);
    expect(concepts.length, 18, reason: 'topped up to the full curriculum');
    final bonjour = concepts.singleWhere((c) => c.seedId == 'bonjour');
    expect(bonjour.id, legacyConcept.id,
        reason: 'the healthy legacy concept was recognized by word match');
    final variantIdsNow = (await db.conceptDao.getVariantsByConcept(bonjour.id))
        .map((v) => v.id)
        .toSet();
    expect(variantIdsNow, legacyVariantIds,
        reason: 'existing variant rows (which may carry FSRS progress) must '
            'never be replaced');
  });

  test(
      'healing: a list whose concepts lost every variant to the pre-v3 import '
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
      expect((await db.conceptDao.getVariantsByConcept(c.id)).length,
          greaterThanOrEqualTo(2));
    }
  });

  test('en>de seeds the 5 universal lists — no Korean particles list',
      () async {
    await seed(source: 'en', target: 'de');

    final lists = await repo.watchMyLists().first;
    expect(lists.length, 5,
        reason: 'the ko-scoped particles list must not seed for de');
    expect(lists.every((l) => l.langA == 'en' && l.langB == 'de'), isTrue);
    expect(lists.map((l) => l.name), contains('Numbers & time'),
        reason: 'names resolve UI locale → source language; both are en here');
    for (final l in lists) {
      final concepts = await db.conceptDao.getConceptsByList(l.id);
      for (final c in concepts) {
        final langs = (await db.conceptDao.getVariantsByConcept(c.id))
            .map((v) => v.langCode)
            .toSet();
        expect(langs.containsAll({'en', 'de'}), isTrue);
      }
    }
  });

  test('both directions of a pair are distinct curricula', () async {
    await seed(source: 'fr', target: 'ko');
    await seed(source: 'ko', target: 'fr');

    final lists = await repo.watchMyLists().first;
    // fr>ko has the particles list (target ko), ko>fr does not.
    expect(lists.where((l) => l.seedId?.endsWith(':fr>ko') ?? false).length, 6);
    expect(lists.where((l) => l.seedId?.endsWith(':ko>fr') ?? false).length, 5);
  });

  test('an unknown language layer seeds nothing and does NOT set the flag',
      () async {
    await seed(source: 'fr', target: 'xx');
    expect(await repo.watchMyLists().first, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(StarterSeeder.flagKeyFor('u1', 'fr', 'xx')), isNull,
        reason: 'a later release shipping the layer must still seed');
  });

  test('deleting everything later does NOT re-seed (flag is sticky)', () async {
    await seed();
    for (final l in await repo.watchMyLists().first) {
      await repo.deleteList(l.id);
    }
    await seed();
    expect(await repo.watchMyLists().first, isEmpty);
  });

  test('the seedStarterListsProvider seeds the persisted default pair',
      () async {
    SharedPreferences.setMockInitialValues({
      'settings_default_lang_a': 'fr',
      'settings_default_lang_b': 'ko',
    });
    final c = makeContainer();
    // Keep an active listener like the home screen's ref.watch does —
    // defaultPairProvider's async prefs load invalidates the seed provider
    // mid-flight, and a bare .future read would never see the recompute.
    c.listen(seedStarterListsProvider, (_, __) {});
    await c.read(seedStarterListsProvider.future);
    expect((await repo.watchMyLists().first).length, 6);
  });
}
