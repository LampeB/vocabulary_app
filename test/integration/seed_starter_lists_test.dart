// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import '../helpers/fake_remote.dart';

/// First-login seeding of the bundled starter lists (the REAL asset, so this
/// also validates the shipped content imports cleanly): 6 lists / 111
/// concepts for a brand-new user, once ever, never over existing data.

AppUser _user(String id) => AppUser(
      id: id,
      email: 't@t.fr',
      username: 'thomas',
      subscriptionType: SubscriptionType.free,
      createdAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // rootBundle for the asset

  late AppDatabase db;
  late VocabularyRepositoryImpl repo;

  ProviderContainer makeContainer({String userId = 'u1'}) {
    final c = ProviderContainer(overrides: [
      vocabularyRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(_user(userId)),
      syncOnLoginProvider.overrideWith((ref) async {}),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = VocabularyRepositoryImpl(
        db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u1', db);
  });
  tearDown(() => db.close());

  test('a brand-new user gets the 6 starter lists with all their words',
      () async {
    final c = makeContainer();

    await c.read(seedStarterListsProvider.future);

    final lists = await repo.watchMyLists().first;
    expect(lists.length, 6);
    expect(lists.map((l) => l.name),
        contains('Les particules essentielles'));
    expect(lists.every((l) => l.origin == 'starter'), isTrue,
        reason: 'seeded lists must be quota-exempt');
    var totalConcepts = 0;
    for (final l in lists) {
      totalConcepts += (await db.conceptDao.getConceptsByList(l.id)).length;
    }
    expect(totalConcepts, 111);
  });

  test('seeding is once-ever: a second run adds nothing', () async {
    final c1 = makeContainer();
    await c1.read(seedStarterListsProvider.future);

    final c2 = makeContainer();
    await c2.read(seedStarterListsProvider.future);

    expect((await repo.watchMyLists().first).length, 6);
  });

  test('a user who already has lists is never seeded', () async {
    await repo.createList(name: 'Ma liste');
    final c = makeContainer();

    await c.read(seedStarterListsProvider.future);

    final lists = await repo.watchMyLists().first;
    expect(lists.length, 1);
    expect(lists.single.name, 'Ma liste');
  });

  test('deleting everything later does NOT re-seed (flag is per-user, sticky)',
      () async {
    final c1 = makeContainer();
    await c1.read(seedStarterListsProvider.future);
    for (final l in await repo.watchMyLists().first) {
      await repo.deleteList(l.id);
    }

    final c2 = makeContainer();
    await c2.read(seedStarterListsProvider.future);

    expect(await repo.watchMyLists().first, isEmpty);
  });
}
