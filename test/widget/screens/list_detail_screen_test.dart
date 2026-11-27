// ignore_for_file: invalid_use_of_internal_member
import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/datasources/remote/vocab_assistant_datasource.dart';
import 'package:vocab_kr/presentation/providers/lists/vocab_assistant_provider.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/screens/lists/list_detail_screen.dart';
import '../../helpers/fake_remote.dart';
import '../../helpers/pump_screen.dart';

class _PairAssistant implements VocabAssistantDataSource {
  String? source, target;
  List<WordPairSuggestion> examples = [];
  @override
  Future<Result<ThemedSuggestions>> suggest(
      {required String sourceLang,
      required String targetLang,
      required List<WordPairSuggestion> existingPairs,
      int count = 8}) async {
    source = sourceLang;
    target = targetLang;
    examples = existingPairs;
    return const Success(ThemedSuggestions(theme: 'Test', pairs: [
      WordPairSuggestion(source: 'new-source', target: 'new-target'),
    ]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  String? pushedRoute;
  QuizArgs? launchedQuiz;

  Future<void> pump(WidgetTester tester,
      {bool premium = true,
      int? forceWordCount,
      String langA = 'fr',
      String langB = 'ko',
      String wordA = 'chat',
      String wordB = '고양이',
      _PairAssistant? assistant}) async {
    pushedRoute = null;
    launchedQuiz = null;
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      repo = VocabularyRepositoryImpl(
          db.vocabularyListDao, db.conceptDao, FakeRemote(), 'u', db);
      final list =
          (await repo.createList(name: 'Animaux', langA: langA, langB: langB))
              .valueOrNull!;
      listId = list.id;
      await repo.addConceptWithVariants(
          listId: listId,
          wordA: wordA,
          wordB: wordB,
          langA: langA,
          langB: langB);
      await repo.addConceptWithVariants(
          listId: listId,
          wordA: 'chien',
          wordB: '개',
          langA: langA,
          langB: langB);
      if (forceWordCount != null) {
        // Simulate a list at the free-plan word quota without 50 inserts.
        await db.vocabularyListDao.updateWordCount(listId, forceWordCount);
      }
    });
    await pumpScreen(
      tester,
      screen: ListDetailScreen(listId: listId),
      overrides: [
        vocabularyRepositoryProvider.overrideWithValue(repo),
        isPremiumProvider.overrideWithValue(premium),
        if (assistant != null)
          vocabAssistantProvider.overrideWithValue(assistant),
      ],
      routes: [
        GoRoute(
          path: '/paywall',
          pageBuilder: (_, state) {
            pushedRoute = '/paywall';
            return const MaterialPage<void>(child: Scaffold(body: SizedBox()));
          },
        ),
        GoRoute(
          path: '/quiz',
          pageBuilder: (_, state) {
            launchedQuiz = state.extra! as QuizArgs;
            return const MaterialPage<void>(child: Scaffold(body: SizedBox()));
          },
        ),
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

  for (final pair in [
    ('en', 'ko', 'cat', '고양이'),
    ('ko', 'fr', '고양이', 'chat')
  ]) {
    testWidgets(
        'suggestions preserve ${pair.$1} to ${pair.$2} through insertion',
        (tester) async {
      final assistant = _PairAssistant();
      await pump(tester,
          langA: pair.$1,
          langB: pair.$2,
          wordA: pair.$3,
          wordB: pair.$4,
          assistant: assistant);
      await tester.tap(byKey(WidgetKeys.listDetailMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('list_detail.menu_ai_suggest'.tr()));
      await tester.pumpAndSettle();
      expect(assistant.source, pair.$1);
      expect(assistant.target, pair.$2);
      expect(assistant.examples.first.source, pair.$3);
      expect(assistant.examples.first.target, pair.$4);
      await tester.tap(
          find.text('list_detail.ai_add_selected'.tr(namedArgs: {'n': '1'})));
      await tester.pumpAndSettle();
      final added = await tester.runAsync(() async {
        final concepts = await db.conceptDao.getConceptsByList(listId);
        for (final concept in concepts) {
          final variants = await db.conceptDao.getVariantsByConcept(concept.id);
          if (variants.any((v) => v.word == 'new-source')) return variants;
        }
        return null;
      });
      expect(
          added!.singleWhere((v) => v.word == 'new-source').langCode, pair.$1);
      expect(
          added.singleWhere((v) => v.word == 'new-target').langCode, pair.$2);
      await unmountScreen(tester);
    });
    testWidgets('displays and edits ordered ${pair.$1} to ${pair.$2} variants',
        (tester) async {
      await pump(tester,
          langA: pair.$1, langB: pair.$2, wordA: pair.$3, wordB: pair.$4);
      expect(find.text(pair.$3), findsOneWidget);
      expect(find.text(pair.$4), findsOneWidget);
      await enterEditMode(tester);
      await tester.tap(byKey(WidgetKeys.conceptEditIcon(pair.$3)));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextFormField>(byKey(WidgetKeys.editWordFr))
              .controller!
              .text,
          pair.$3);
      expect(
          tester
              .widget<TextFormField>(byKey(WidgetKeys.editWordKo))
              .controller!
              .text,
          pair.$4);
      await tester.enterText(byKey(WidgetKeys.editWordFr), '${pair.$3} edited');
      await tester.tap(byKey(WidgetKeys.editWordConfirm));
      await tester.pumpAndSettle();
      expect(find.text('${pair.$3} edited'), findsOneWidget);
      await unmountScreen(tester);
    });
  }

  testWidgets('hands-free quick action starts a hands-free list quiz',
      (tester) async {
    await pump(tester);

    await tester.tap(byKey(WidgetKeys.listDetailHandsFree));
    await tester.pumpAndSettle();

    expect(launchedQuiz?.mode, QuizMode.handsFree);
    expect(launchedQuiz?.source, QuizSource.list);
    expect(launchedQuiz?.listId, listId);
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
    final concepts =
        await tester.runAsync(() => db.conceptDao.getConceptsByList(listId));
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

  testWidgets('free plan at the word quota: adding a word routes to /paywall',
      (tester) async {
    await pump(tester, premium: false, forceWordCount: 50);

    await tester.tap(byKey(WidgetKeys.listDetailAddWord));
    await tester.pumpAndSettle();
    await tester.enterText(byKey(WidgetKeys.addWordFr), 'trop');
    await tester.enterText(byKey(WidgetKeys.addWordKo), '초과');
    await tester.tap(byKey(WidgetKeys.addWordConfirm));
    await tester.pumpAndSettle();

    expect(pushedRoute, '/paywall');
    expect(find.text('trop'), findsNothing);
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
