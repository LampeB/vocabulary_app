// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:easy_localization/easy_localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/core/languages.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/domain/repositories/vocabulary_repository.dart';
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
import '../../helpers/rendered_text_contrast.dart';

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
  final activeRepository = StateProvider<VocabularyRepository?>((ref) => null);

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
    ThemeMode themeMode = ThemeMode.light,
    Stream<VocabularyList?> Function()? metadata,
    bool settle = true,
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
      themeMode: themeMode,
      settle: settle,
      overrides: [
        vocabularyRepositoryProvider.overrideWith(
          (ref) => ref.watch(activeRepository) ?? repo,
        ),
        if (metadata != null)
          listInfoProvider.overrideWith((ref, _) => metadata()),
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

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'list actions have distinct accessible names and contrast in $theme',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, themeMode: theme);
        for (final (key, label) in [
          (WidgetKeys.listDetailHandsFree, 'quiz_setup.mode_hands_free_label'),
          (WidgetKeys.listDetailAddWord, 'list_detail.add_word_bar'),
        ]) {
          final finder = find.byKey(ValueKey(key));
          expect(
            tester.getSemantics(finder),
            matchesSemantics(
              label: label.tr(),
              isButton: true,
              isEnabled: true,
              hasEnabledState: true,
              isFocusable: true,
              hasTapAction: true,
              hasFocusAction: true,
            ),
          );
          final button = tester.widget<OutlinedButton>(finder);
          final style = button.style!;
          final fill = style.backgroundColor!.resolve({})!;
          final ink = style.foregroundColor!.resolve({})!;
          final values = [
            fill.computeLuminance(),
            Color.alphaBlend(ink, fill).computeLuminance(),
          ]..sort();
          expect(
            (values.last + .05) / (values.first + .05),
            greaterThanOrEqualTo(3),
          );
        }
        semantics.dispose();
        await unmountScreen(tester);
      },
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

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'Done and the word language labels have readable contrast in $theme',
      (tester) async {
        useFallbackFontsForContrast();
        await pump(tester, themeMode: theme);
        await enterEditMode(tester);
        for (final label in [
          find.text('list_detail.action_done'.tr()),
          find.text(Languages.displayName('fr')).first,
          find.text(Languages.displayName('ko')).first,
        ]) {
          expect(
            await renderedTextContrast(tester, label),
            greaterThanOrEqualTo(4.5),
            reason: tester.widget<Text>(label).data,
          );
        }
        await tester.tap(find.text('list_detail.action_done'.tr()));
        await tester.pumpAndSettle();
        expect(byKey(WidgetKeys.listDetailMenu), findsOneWidget);
        await unmountScreen(tester);
      },
    );
  }

  testWidgets('Add waits for the confirmed pair after a metadata read fails', (
    tester,
  ) async {
    final queries = <StreamController<VocabularyList?>>[];
    await pump(
      tester,
      langA: 'ko',
      langB: 'fr',
      wordA: '고양이',
      wordB: 'chat',
      settle: false,
      metadata: () {
        final query = StreamController<VocabularyList?>();
        queries.add(query);
        return query.stream;
      },
    );
    final add = byKey(WidgetKeys.listDetailAddWord);
    expect(add, findsNothing);
    expect(find.byType(Dialog), findsNothing);

    queries.single.addError(StateError('metadata unavailable'));
    await tester.pumpAndSettle();
    expect(add, findsNothing);
    expect(find.text('common.error'.tr()), findsOneWidget);
    expect(find.textContaining('metadata unavailable'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'common.retry'.tr()));
    await tester.pump();
    expect(queries, hasLength(2));
    expect(add, findsNothing);

    queries.last.add(null);
    await tester.pumpAndSettle();
    expect(add, findsNothing);

    final list = await tester.runAsync(
      () async => (await repo.getListById(listId)).valueOrNull!,
    );
    queries.last.add(list);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    final fieldA = byKey(WidgetKeys.addWordFr);
    final fieldB = byKey(WidgetKeys.addWordKo);
    expect(
      find.descendant(
        of: fieldA,
        matching: find.text(Languages.displayName('ko')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: fieldB,
        matching: find.text(Languages.displayName('fr')),
      ),
      findsOneWidget,
    );
    await tester.enterText(fieldA, '사과');
    await tester.enterText(fieldB, 'pomme');
    await tester.tap(byKey(WidgetKeys.addWordConfirm));
    await tester.pumpAndSettle();

    final words = await tester.runAsync(() async {
      final concepts = await db.conceptDao.getConceptsByList(listId);
      return {
        for (final concept in concepts)
          for (final word in await db.conceptDao.getVariantsByConcept(
            concept.id,
          ))
            word.word: word.langCode,
      };
    });
    expect(words, containsPair('사과', 'ko'));
    expect(words, containsPair('pomme', 'fr'));
    await unmountScreen(tester);
    for (final query in queries) {
      unawaited(query.close());
    }
  });

  for (final edit in [false, true]) {
    testWidgets(
      'a changed pair rejects an already open ${edit ? 'Edit' : 'Add'} form',
      (tester) async {
        await pump(
          tester,
          langA: 'ko',
          langB: 'fr',
          wordA: '고양이',
          wordB: 'chat',
        );
        if (edit) await enterEditMode(tester);
        await tester.tap(
          edit
              ? byKey(WidgetKeys.conceptEditIcon('고양이'))
              : byKey(WidgetKeys.listDetailAddWord),
        );
        await tester.pumpAndSettle();

        final fieldA = byKey(
          edit ? WidgetKeys.editWordFr : WidgetKeys.addWordFr,
        );
        final fieldB = byKey(
          edit ? WidgetKeys.editWordKo : WidgetKeys.addWordKo,
        );
        final save = byKey(
          edit ? WidgetKeys.editWordConfirm : WidgetKeys.addWordConfirm,
        );
        await tester.enterText(fieldA, '사과');
        await tester.enterText(fieldB, 'pomme');
        final changed = await tester.runAsync(() async {
          final list = (await repo.getListById(listId)).valueOrNull!;
          return repo.updateList(list.copyWith(langA: 'en', langB: 'ko'));
        });
        expect(changed?.isSuccess, isTrue);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();

        expect(find.text('list_detail.word_pair_changed'.tr()), findsOneWidget);
        expect(
          find.descendant(of: fieldA, matching: find.text('사과')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: fieldB, matching: find.text('pomme')),
          findsOneWidget,
        );
        final words = await tester.runAsync(() async {
          final concepts = await db.conceptDao.getConceptsByList(listId);
          return {
            for (final concept in concepts)
              for (final word in await db.conceptDao.getVariantsByConcept(
                concept.id,
              ))
                word.word: word.langCode,
          };
        });
        expect(words, containsPair('고양이', 'ko'));
        expect(words, containsPair('chat', 'fr'));
        expect(words, isNot(contains('사과')));
        expect(words, isNot(contains('pomme')));
        await unmountScreen(tester);
      },
    );
  }

  testWidgets('a word form opened by one account cannot save after switching', (
    tester,
  ) async {
    await pump(tester);
    final scope = ProviderScope.containerOf(
      tester.element(byKey(WidgetKeys.screenListDetail)),
    );
    await tester.tap(byKey(WidgetKeys.listDetailAddWord));
    await tester.pumpAndSettle();
    await tester.enterText(byKey(WidgetKeys.addWordFr), 'pomme');
    await tester.enterText(byKey(WidgetKeys.addWordKo), '사과');
    scope.read(activeRepository.notifier).state = VocabularyRepositoryImpl(
      db.vocabularyListDao,
      db.conceptDao,
      FakeRemote(),
      'another-account',
      db,
    );
    await tester.pumpAndSettle();
    await tester.tap(byKey(WidgetKeys.addWordConfirm));
    await tester.pumpAndSettle();

    expect(find.text('list_detail.word_pair_changed'.tr()), findsOneWidget);
    final concepts = await tester.runAsync(
      () => db.conceptDao.getConceptsByList(listId),
    );
    expect(concepts, hasLength(2));
    await unmountScreen(tester);
  });

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
      expect(find.byType(Dialog), findsOneWidget);
      await unmountScreen(tester);
    });
  }

  for (final (locale, required) in [
    ('fr', 'Requis'),
    ('en', 'Required'),
    ('ko', '필수'),
  ]) {
    for (final edit in [false, true]) {
      testWidgets(
        '${edit ? 'Edit' : 'Add'} keeps both fields and Save reachable in $locale with keyboard',
        (tester) async {
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
          await pump(
            tester,
            langA: 'ko',
            langB: 'fr',
            wordA: '고양이',
            wordB: 'chat',
          );
          if (edit) await enterEditMode(tester);
          tester.view.physicalSize = const Size(568, 320);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
          final launch = edit
              ? byKey(WidgetKeys.conceptEditIcon('고양이'))
              : byKey(WidgetKeys.listDetailAddWord);
          await tester.ensureVisible(launch);
          await tester.pumpAndSettle();
          expect(launch.hitTestable(), findsOneWidget);
          await tester.tap(launch);
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          await tester.pumpAndSettle();

          final dialog = find.byType(Dialog);
          final scroll = find.descendant(
            of: dialog,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          );
          final title = find.text(
            (edit
                    ? 'list_detail.edit_dialog_title'
                    : 'list_detail.add_dialog_title')
                .tr(),
          );
          expect(find.ancestor(of: title, matching: scroll), findsOneWidget);
          expect(tester.getRect(scroll).height, greaterThan(0));
          expect(tester.getRect(scroll).bottom, lessThanOrEqualTo(140));
          expect(
            tester.state<ScrollableState>(scroll).position.maxScrollExtent,
            greaterThan(0),
          );
          final cue = find.descendant(
            of: dialog,
            matching: find.text('v3.scroll_hint'.tr()),
          );
          final cueOpacity = find
              .ancestor(of: cue, matching: find.byType(AnimatedOpacity))
              .first;
          expect(tester.widget<AnimatedOpacity>(cueOpacity).opacity, 1);
          expect(tester.takeException(), isNull);

          final fieldA = byKey(
            edit ? WidgetKeys.editWordFr : WidgetKeys.addWordFr,
          );
          final fieldB = byKey(
            edit ? WidgetKeys.editWordKo : WidgetKeys.addWordKo,
          );
          final save = byKey(
            edit ? WidgetKeys.editWordConfirm : WidgetKeys.addWordConfirm,
          );
          expect(find.ancestor(of: save, matching: scroll), findsOneWidget);

          Future<void> reach(Finder control) async {
            await tester.pumpAndSettle();
            await Scrollable.ensureVisible(
              tester.element(control),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            expect(
              control.hitTestable(),
              findsOneWidget,
              reason:
                  'control ${tester.getRect(control)} within viewport ${tester.getRect(scroll)}',
            );
          }

          if (edit) {
            await reach(fieldA);
            await tester.enterText(fieldA, '');
            await reach(fieldB);
            await tester.enterText(fieldB, '');
            await reach(save);
            await tester.tap(save);
            await tester.pumpAndSettle();
            for (final field in [fieldA, fieldB]) {
              expect(
                tester.state<FormFieldState<String>>(field).errorText,
                required,
              );
            }
          }
          await reach(fieldA);
          await tester.enterText(fieldA, '사과');
          await reach(fieldB);
          await tester.enterText(fieldB, 'pomme');
          await reach(save);
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(dialog, findsNothing);
          expect(tester.view.viewInsets.bottom, 180);
          expect(tester.takeException(), isNull);

          final words = await tester.runAsync(() async {
            final concepts = await db.conceptDao.getConceptsByList(listId);
            return {
              for (final concept in concepts)
                for (final word in await db.conceptDao.getVariantsByConcept(
                  concept.id,
                ))
                  word.word: word.langCode,
            };
          });
          expect(words, containsPair('사과', 'ko'));
          expect(words, containsPair('pomme', 'fr'));
          await unmountScreen(tester);
        },
      );
    }
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
