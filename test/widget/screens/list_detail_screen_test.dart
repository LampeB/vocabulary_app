// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';
import 'package:vocab_kr/presentation/screens/lists/list_detail_screen.dart';
import '../../helpers/fake_remote.dart';
import '../../helpers/pump_screen.dart';

/// List-detail screen wired to a REAL repository on in-memory drift: word
/// tiles render from the live stream, add/edit/delete flow through
/// listActionsProvider and update the UI. The edit case doubles as the
/// regression test for the variantsProvider-not-invalidated bug (a stale tile
/// after editing a word, originally caught by E2E).

void main() {
  setUpAll(initTestLocalization);

  late AppDatabase db;
  late VocabularyRepositoryImpl repo;
  late String listId;

  // drift awaits deadlock under testWidgets' FakeAsync zone (nothing flushes
  // their microtasks outside a pump), so all direct DB work — seeding and
  // assertions — must run under tester.runAsync.
  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      repo = VocabularyRepositoryImpl(
          db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u', db);
      final list = (await repo.createList(name: 'Animaux')).valueOrNull!;
      listId = list.id;
      await repo.addConceptWithVariants(
          listId: listId, frWord: 'chat', koWord: '고양이');
      await repo.addConceptWithVariants(
          listId: listId, frWord: 'chien', koWord: '개');
    });
    await pumpScreen(
      tester,
      screen: ListDetailScreen(listId: listId),
      overrides: [
        vocabularyRepositoryProvider.overrideWithValue(repo),
        isPremiumProvider.overrideWithValue(true),
      ],
    );
  }

  Finder byKey(String key) => find.byKey(ValueKey(key));

  Future<void> enterEditMode(WidgetTester tester) async {
    await tester.tap(byKey(WidgetKeys.listDetailMenu));
    await tester.pumpAndSettle();
    await tester.tap(byKey(WidgetKeys.listDetailEditItem));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the list name and its word tiles', (tester) async {
    await pump(tester);

    expect(byKey(WidgetKeys.screenListDetail), findsOneWidget);
    expect(find.text('Animaux'), findsOneWidget);
    expect(find.text('chat'), findsOneWidget);
    expect(find.text('고양이'), findsOneWidget);
    expect(find.text('chien'), findsOneWidget);
    await unmountScreen(tester);
  });

  testWidgets('adding a word through the dialog shows the new tile',
      (tester) async {
    await pump(tester);

    await tester.tap(byKey(WidgetKeys.listDetailAddWord));
    await tester.pumpAndSettle();
    await tester.enterText(byKey(WidgetKeys.addWordFr), 'maison');
    await tester.enterText(byKey(WidgetKeys.addWordKo), '집');
    await tester.tap(byKey(WidgetKeys.addWordConfirm));
    await tester.pumpAndSettle();

    expect(find.text('maison'), findsOneWidget);
    expect(find.text('집'), findsOneWidget);
    // Persisted, not just painted.
    final concepts = await tester
        .runAsync(() => db.conceptDao.getConceptsByList(listId));
    expect(concepts!.length, 3);
    await unmountScreen(tester);
  });

  testWidgets(
      'editing a word updates the tile (variantsProvider invalidation '
      'regression)', (tester) async {
    await pump(tester);
    await enterEditMode(tester);

    await tester.tap(byKey(WidgetKeys.conceptEditIcon('chat')));
    await tester.pumpAndSettle();
    await tester.enterText(byKey(WidgetKeys.editWordFr), 'chaton');
    await tester.tap(byKey(WidgetKeys.editWordConfirm));
    await tester.pumpAndSettle();

    // The bug: the tile kept showing the stale cached variant after an edit.
    expect(find.text('chaton'), findsOneWidget);
    expect(find.text('chat'), findsNothing);
    await unmountScreen(tester);
  });

  testWidgets('deleting a word removes its tile after confirmation',
      (tester) async {
    await pump(tester);
    await enterEditMode(tester);

    await tester.tap(byKey(WidgetKeys.conceptDeleteIcon('chien')));
    await tester.pumpAndSettle();
    await tester.tap(byKey(WidgetKeys.deleteWordConfirm));
    await tester.pumpAndSettle();

    expect(find.text('chien'), findsNothing);
    expect(find.text('chat'), findsOneWidget); // the other one survives
    await unmountScreen(tester);
  });
}
