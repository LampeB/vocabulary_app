// ignore_for_file: invalid_use_of_internal_member
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
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
  _PairAssistant({
    this.pairs = const [
      WordPairSuggestion(source: 'new-source', target: 'new-target'),
    ],
  });
  final List<WordPairSuggestion> pairs;
  String? source, target;
  List<WordPairSuggestion> examples = [];
  @override
  Future<Result<ThemedSuggestions>> suggest({
    required String sourceLang,
    required String targetLang,
    required List<WordPairSuggestion> existingPairs,
    int count = 8,
  }) async {
    source = sourceLang;
    target = targetLang;
    examples = existingPairs;
    return Success(ThemedSuggestions(theme: 'Test', pairs: pairs));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CanonicalDetailRemote extends FakeRemote {
  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(
    String token,
  ) async => const Success({
    'name': 'Imported title',
    'concepts': [
      {
        'id': 'source-concept',
        'word_variants': [
          {
            'id': 'fr',
            'word': 'mot importé',
            'lang_code': 'fr',
            'is_primary': true,
          },
          {'id': 'ko', 'word': '단어', 'lang_code': 'ko', 'is_primary': true},
        ],
      },
    ],
  });

  @override
  Future<Result<Map<String, dynamic>>> upsertList(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async => Success({...data, 'name': 'Canonical title'});

  @override
  Future<Result<Map<String, dynamic>>> upsertVariant(
    Map<String, dynamic> data, {
    bool insertOnly = false,
    Map<String, dynamic>? changes,
  }) async => Success(
    data['lang_code'] == 'fr' ? {...data, 'word': 'mot canonique'} : data,
  );
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

  Future<void> pump(
    WidgetTester tester, {
    bool premium = true,
    int? forceWordCount,
    String langA = 'fr',
    String langB = 'ko',
    String wordA = 'chat',
    String wordB = '고양이',
    _PairAssistant? assistant,
    _CanonicalDetailRemote? canonicalRemote,
  }) async {
    pushedRoute = null;
    launchedQuiz = null;
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      repo = VocabularyRepositoryImpl(
        db.vocabularyListDao,
        db.conceptDao,
        canonicalRemote ?? FakeRemote(),
        'u',
        db,
      );
      if (canonicalRemote != null) {
        listId = (await repo.importFromShareToken('shared')).valueOrNull!.id;
        return;
      }
      final list = (await repo.createList(
        name: 'Animaux',
        langA: langA,
        langB: langB,
      )).valueOrNull!;
      listId = list.id;
      await repo.addConceptWithVariants(
        listId: listId,
        wordA: wordA,
        wordB: wordB,
        langA: langA,
        langB: langB,
      );
      await repo.addConceptWithVariants(
        listId: listId,
        wordA: 'chien',
        wordB: '개',
        langA: langA,
        langB: langB,
      );
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

  testWidgets(
    'an open list sees its canonical title and word after import ack',
    (tester) async {
      final remote = _CanonicalDetailRemote();
      await pump(tester, canonicalRemote: remote);
      expect(find.text('Imported title'), findsOneWidget);
      expect(find.text('mot importé'), findsOneWidget);

      int? pushed;
      final drain = PushSync(
        db.vocabularyListDao,
        db.conceptDao,
        db.progressDao,
        db.reviewEventDao,
        remote,
        userId: 'u',
      ).pushAll().then((count) => pushed = count);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(pushed, 4);
      await drain;

      expect(find.text('Canonical title'), findsOneWidget);
      expect(find.text('mot canonique'), findsOneWidget);
      expect(find.text('Imported title'), findsNothing);
      expect(find.text('mot importé'), findsNothing);
      await unmountScreen(tester);
    },
  );

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

  testWidgets(
    'long list title wraps in the scroller at 320x568 with double text',
    (tester) async {
      await pump(tester);
      const name = 'Vocabulaire pour saluer et rencontrer mes nouveaux amis';
      await tester.runAsync(() => repo.renameList(listId, name));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      final title = find.text(name);
      expect(
        find.ancestor(of: title, matching: find.byType(Scrollable)),
        findsOneWidget,
      );
      final titleRect = tester.getRect(title);
      final viewport = tester.getRect(find.byType(Scrollable).first);
      expect(titleRect.top, greaterThanOrEqualTo(viewport.top));
      final paragraph = tester.renderObject<RenderParagraph>(title);
      final lastLine = paragraph
          .getBoxesForSelection(
            const TextSelection(
              baseOffset: name.length - 1,
              extentOffset: name.length,
            ),
          )
          .single
          .toRect();
      final lastBottom = paragraph.localToGlobal(lastLine.bottomRight).dy;
      final scroller = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scroller.position.jumpTo(
        (lastBottom - viewport.bottom + 12).clamp(
          0,
          scroller.position.maxScrollExtent,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        paragraph.localToGlobal(lastLine.bottomRight).dy,
        lessThanOrEqualTo(viewport.bottom),
      );
      expect(
        paragraph.localToGlobal(lastLine.topLeft).dy,
        greaterThanOrEqualTo(viewport.top),
      );
      expect(tester.widget<Text>(title).maxLines, isNull);
      final semantics = tester.ensureSemantics();
      final back = byKey(WidgetKeys.listDetailBack);
      expect(
        tester.getSemantics(back).getSemanticsData().tooltip,
        'common.back'.tr(),
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
      await unmountScreen(tester);
    },
  );

  for (final (locale, kind, required) in [
    ('fr', 'LISTE DE VOCABULAIRE', 'Requis'),
    ('en', 'VOCABULARY LIST', 'Required'),
    ('ko', '단어 목록', '필수'),
  ]) {
    testWidgets('list heading and both empty field errors use $locale', (
      tester,
    ) async {
      final raw = (await tester.runAsync(
        () => rootBundle.loadString('assets/translations/$locale.json'),
      ))!;
      final translations = Translations(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      Localization.load(
        Locale(locale),
        translations: translations,
        fallbackTranslations: translations,
      );
      addTearDown(initTestLocalization);
      await pump(tester);

      expect(find.text(kind), findsOneWidget);
      await tester.tap(byKey(WidgetKeys.listDetailAddWord));
      await tester.pumpAndSettle();
      await tester.tap(byKey(WidgetKeys.addWordConfirm));
      await tester.pumpAndSettle();

      for (final field in [WidgetKeys.addWordFr, WidgetKeys.addWordKo]) {
        expect(
          tester.state<FormFieldState<String>>(byKey(field)).errorText,
          required,
        );
      }
      expect(find.byType(AlertDialog), findsOneWidget);
      await unmountScreen(tester);
    });
  }

  for (final pair in [
    ('en', 'ko', 'cat', '고양이'),
    ('ko', 'fr', '고양이', 'chat'),
  ]) {
    testWidgets(
      'suggestions preserve ${pair.$1} to ${pair.$2} through insertion',
      (tester) async {
        final assistant = _PairAssistant();
        await pump(
          tester,
          langA: pair.$1,
          langB: pair.$2,
          wordA: pair.$3,
          wordB: pair.$4,
          assistant: assistant,
        );
        await tester.tap(byKey(WidgetKeys.listDetailMenu));
        await tester.pumpAndSettle();
        await tester.tap(find.text('list_detail.menu_ai_suggest'.tr()));
        await tester.pumpAndSettle();
        expect(assistant.source, pair.$1);
        expect(assistant.target, pair.$2);
        expect(
          assistant.examples.map((p) => (p.source, p.target)),
          contains((pair.$3, pair.$4)),
        );
        await tester.tap(
          find.text('list_detail.ai_add_selected'.tr(namedArgs: {'n': '1'})),
        );
        await tester.pumpAndSettle();
        final added = await tester.runAsync(() async {
          final concepts = await db.conceptDao.getConceptsByList(listId);
          for (final concept in concepts) {
            final variants = await db.conceptDao.getVariantsByConcept(
              concept.id,
            );
            if (variants.any((v) => v.word == 'new-source')) return variants;
          }
          return null;
        });
        expect(
          added!.singleWhere((v) => v.word == 'new-source').langCode,
          pair.$1,
        );
        expect(
          added.singleWhere((v) => v.word == 'new-target').langCode,
          pair.$2,
        );
        await unmountScreen(tester);
      },
    );
    testWidgets(
      'displays and edits ordered ${pair.$1} to ${pair.$2} variants',
      (tester) async {
        await pump(
          tester,
          langA: pair.$1,
          langB: pair.$2,
          wordA: pair.$3,
          wordB: pair.$4,
        );
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
          pair.$3,
        );
        expect(
          tester
              .widget<TextFormField>(byKey(WidgetKeys.editWordKo))
              .controller!
              .text,
          pair.$4,
        );
        await tester.enterText(
          byKey(WidgetKeys.editWordFr),
          '${pair.$3} edited',
        );
        await tester.tap(byKey(WidgetKeys.editWordConfirm));
        await tester.pumpAndSettle();
        expect(find.text('${pair.$3} edited'), findsOneWidget);
        await unmountScreen(tester);
      },
    );
  }

  testWidgets('hands-free quick action starts a hands-free list quiz', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(byKey(WidgetKeys.listDetailHandsFree));
    await tester.pumpAndSettle();

    expect(launchedQuiz?.mode, QuizMode.handsFree);
    expect(launchedQuiz?.source, QuizSource.list);
    expect(launchedQuiz?.listId, listId);
    await unmountScreen(tester);
  });

  testWidgets('adding a word through the dialog shows the new tile', (
    tester,
  ) async {
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
    final concepts = await tester.runAsync(
      () => db.conceptDao.getConceptsByList(listId),
    );
    expect(concepts!.length, 3);
    await unmountScreen(tester);
  });

  testWidgets('editing a word updates the tile (variantsProvider invalidation '
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

  testWidgets('free plan at the word quota: adding a word routes to /paywall', (
    tester,
  ) async {
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

  testWidgets('partial suggestions keep refused selections and show upgrade', (
    tester,
  ) async {
    final assistant = _PairAssistant(
      pairs: const [
        WordPairSuggestion(source: 'first addition', target: '첫 추가'),
        WordPairSuggestion(source: 'refused addition', target: '거부된 추가'),
      ],
    );
    await pump(
      tester,
      premium: false,
      forceWordCount: 49,
      assistant: assistant,
    );
    await tester.tap(byKey(WidgetKeys.listDetailMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('list_detail.menu_ai_suggest'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('list_detail.ai_add_selected'.tr(namedArgs: {'n': '2'})),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'list_detail.ai_add_partial'.tr(
          namedArgs: {'added': '1', 'remaining': '1'},
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('list_detail.ai_add_quota'.tr()), findsOneWidget);
    final checks = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(checks[0].onChanged, isNull);
    expect(checks[1].value, isTrue);
    expect(checks[1].onChanged, isNotNull);
    final persisted = await tester.runAsync(() async {
      final concepts = await db.conceptDao.getConceptsByList(listId);
      return (await db.conceptDao.getVariantsByConceptIds(
        concepts.map((c) => c.id).toList(),
        'fr',
      )).map((v) => v.word).toList();
    });
    expect(persisted, contains('first addition'));
    expect(persisted, isNot(contains('refused addition')));
    await tester.tap(find.text('profile.upgrade_button'.tr()));
    await tester.pumpAndSettle();
    expect(pushedRoute, '/paywall');
    await unmountScreen(tester);
  });

  testWidgets('deleting a word removes its tile after confirmation', (
    tester,
  ) async {
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
