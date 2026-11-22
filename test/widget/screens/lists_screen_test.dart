// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';
import 'package:vocab_kr/presentation/screens/lists/lists_screen.dart';
import '../../helpers/fake_remote.dart';
import '../../helpers/pump_screen.dart';

/// Lists screen against a REAL repository on in-memory drift: tiles render
/// from the live stream, the FAB dialog creates and persists a list, tiles
/// navigate to detail, and the free-plan quota path routes to /paywall.

void main() {
  setUpAll(initTestLocalization);

  late AppDatabase db;
  late VocabularyRepositoryImpl repo;
  String? pushedRoute;

  Future<void> pump(WidgetTester tester,
      {List<String> seedLists = const [], bool premium = true}) async {
    pushedRoute = null;
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      repo = VocabularyRepositoryImpl(
          db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u', db);
      for (final name in seedLists) {
        await repo.createList(name: name);
      }
    });
    await pumpScreen(
      tester,
      screen: const ListsScreen(),
      overrides: [
        vocabularyRepositoryProvider.overrideWithValue(repo),
        isPremiumProvider.overrideWithValue(premium),
      ],
      routes: [
        for (final r in ['/lists/:id', '/paywall'])
          GoRoute(
            path: r,
            pageBuilder: (_, state) {
              pushedRoute = state.uri.toString();
              return const MaterialPage<void>(
                  child: Scaffold(body: SizedBox()));
            },
          ),
      ],
    );
  }

  Finder byKey(String key) => find.byKey(ValueKey(key));

  // The list tile's menu icon is size 20; the app bar's is the default 24.
  Finder tileMenu() => find.byWidgetPredicate(
      (w) => w is Icon && w.icon == Icons.more_vert && w.size == 20);

  testWidgets('renders seeded lists', (tester) async {
    await pump(tester, seedLists: ['Animaux', 'Cuisine']);

    expect(byKey(WidgetKeys.screenLists), findsOneWidget);
    expect(find.text('Animaux'), findsOneWidget);
    expect(find.text('Cuisine'), findsOneWidget);
    await unmountScreen(tester);
  });

  testWidgets('FAB dialog creates a list, shows its tile and persists it',
      (tester) async {
    await pump(tester);

    await tester.tap(byKey(WidgetKeys.listsFab));
    await tester.pumpAndSettle();
    await tester.enterText(byKey(WidgetKeys.listNameField), 'Voyage');
    await tester.tap(byKey(WidgetKeys.listNameConfirm));
    await tester.pumpAndSettle();

    expect(find.text('Voyage'), findsOneWidget);
    final rows = await tester.runAsync(() => db.vocabularyListDao
        .getUnsyncedLists()); // freshly created lists are unsynced
    expect(rows!.map((r) => r.name), contains('Voyage'));
    await unmountScreen(tester);
  });

  testWidgets('tapping a list tile navigates to its detail route',
      (tester) async {
    await pump(tester, seedLists: ['Animaux']);

    await tester.tap(find.text('Animaux'));
    await tester.pumpAndSettle();

    expect(pushedRoute, startsWith('/lists/'));
    await unmountScreen(tester);
  });

  testWidgets('renaming a list through the tile menu updates the tile',
      (tester) async {
    await pump(tester, seedLists: ['Animaux']);

    await tester.tap(tileMenu()); // tile menu (appbar has its own more_vert)
    await tester.pumpAndSettle();
    await tester.tap(find.text('lists.menu_rename'.tr()));
    await tester.pumpAndSettle();
    await tester.enterText(byKey(WidgetKeys.listNameField), 'Bêtes');
    await tester.tap(byKey(WidgetKeys.listNameConfirm));
    await tester.pumpAndSettle();

    expect(find.text('Bêtes'), findsOneWidget);
    expect(find.text('Animaux'), findsNothing);
    await unmountScreen(tester);
  });

  testWidgets('deleting a list confirms first, then removes the tile',
      (tester) async {
    await pump(tester, seedLists: ['Cuisine']);

    await tester.tap(tileMenu());
    await tester.pumpAndSettle();
    await tester.tap(find.text('lists.menu_delete'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lists.delete_confirm'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('Cuisine'), findsNothing);
    await unmountScreen(tester);
  });

  testWidgets(
      'free plan at the list quota: creating another routes to /paywall',
      (tester) async {
    await pump(tester,
        seedLists: ['A', 'B', 'C'], premium: false); // quota = 3

    await tester.tap(byKey(WidgetKeys.listsFab));
    await tester.pumpAndSettle();
    await tester.enterText(byKey(WidgetKeys.listNameField), 'Une de trop');
    await tester.tap(byKey(WidgetKeys.listNameConfirm));
    await tester.pumpAndSettle();

    expect(pushedRoute, '/paywall');
    expect(find.text('Une de trop'), findsNothing); // not created
    await unmountScreen(tester);
  });
}
