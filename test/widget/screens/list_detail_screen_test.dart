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
import 'package:vocab_kr/core/theme/app_theme.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/core/languages.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/concept.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/entities/word_variant.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/domain/repositories/vocabulary_repository.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/data/sync/push_sync.dart';
import 'package:vocab_kr/data/datasources/remote/vocab_assistant_datasource.dart';
import 'package:vocab_kr/presentation/providers/lists/vocab_assistant_provider.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/navigation/shell_route_visibility.dart';
import 'package:vocab_kr/presentation/screens/lists/list_detail_screen.dart';
import 'package:vocab_kr/presentation/screens/import/import_from_link_screen.dart';
import 'package:vocab_kr/presentation/widgets/list_preview_sheet.dart';
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
  String? translatedWord;
  List<String> contextWords = [];

  @override
  Future<Result<TranslateAssist>> translate({
    required String word,
    required String sourceLang,
    required String targetLang,
    String? theme,
    List<String> existingWords = const [],
  }) async {
    translatedWord = word;
    source = sourceLang;
    target = targetLang;
    contextWords = existingWords;
    return const Success(
      TranslateAssist(
        translations: [TranslationSuggestion(text: '고양이', note: '')],
        voiceFriendly: [
          WordPairSuggestion(source: 'le chat', target: '고양이 한 마리'),
        ],
      ),
    );
  }

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

class _DetailAuthRepository implements AuthRepository {
  final _events = StreamController<AppUser?>.broadcast(sync: true);

  @override
  AppUser? currentUser = _user('u');

  static AppUser _user(String id) => AppUser(
    id: id,
    email: '$id@example.test',
    username: id,
    subscriptionType: SubscriptionType.free,
    createdAt: DateTime(2026),
  );

  void switchAccount(String? id) {
    currentUser = id == null ? null : _user(id);
    _events.add(currentUser);
  }

  Future<void> close() => _events.close();

  @override
  Stream<AppUser?> get authStateChanges => _events.stream;

  @override
  Future<Result<AppUser>> reloadProfile() async => Success(currentUser!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PendingImportRemote extends FakeRemote {
  final reply = Completer<Result<Map<String, dynamic>?>>();
  String? requestedToken;

  @override
  Future<Result<Map<String, dynamic>?>> fetchPublicListByToken(String token) {
    requestedToken = token;
    return reply.future;
  }
}

/// Pauses the result after SQLite has completed the real operation.
class _ObservedDetailRepository extends VocabularyRepositoryImpl {
  _ObservedDetailRepository(AppDatabase db, FakeRemote remote)
    : super(db.vocabularyListDao, db.conceptDao, remote, 'u', db);

  Completer<void>? saveGate;
  Completer<void>? sampleGate;
  bool saveFinished = false;
  int variantObservations = 0;
  final sampleLimits = <int>[];

  @override
  Stream<List<WordVariant>> watchVariants(String conceptId) {
    variantObservations++;
    return super.watchVariants(conceptId);
  }

  @override
  Future<List<({String source, String target})>?> getWordPairSample(
    String listId, {
    required int limit,
    required (String, String) expectedPair,
  }) async {
    sampleLimits.add(limit);
    final pairs = await super.getWordPairSample(
      listId,
      limit: limit,
      expectedPair: expectedPair,
    );
    await sampleGate?.future;
    return pairs;
  }

  Future<Result<T>> _afterSave<T>(Future<Result<T>> operation) async {
    final result = await operation;
    final gate = saveGate;
    if (gate != null) {
      saveFinished = true;
      await gate.future;
    }
    return result;
  }

  @override
  Future<Result<Concept>> addConceptWithVariants({
    required String listId,
    required String wordA,
    required String wordB,
    String langA = 'fr',
    String langB = 'ko',
    String? notes,
    String? category,
  }) => _afterSave(
    super.addConceptWithVariants(
      listId: listId,
      wordA: wordA,
      wordB: wordB,
      langA: langA,
      langB: langB,
      notes: notes,
      category: category,
    ),
  );

  @override
  Future<Result<void>> updateWordPair({
    required String listId,
    required WordVariant variantA,
    required WordVariant variantB,
    required String wordA,
    required String wordB,
  }) => _afterSave(
    super.updateWordPair(
      listId: listId,
      variantA: variantA,
      variantB: variantB,
      wordA: wordA,
      wordB: wordB,
    ),
  );
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
  late _ObservedDetailRepository repo;
  late _DetailAuthRepository auth;
  GoRouter? detailRouter;
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
    _PendingImportRemote? importRemote,
    int extraWords = 0,
    bool seedWords = true,
    ThemeMode themeMode = ThemeMode.light,
    Stream<VocabularyList?> Function()? metadata,
    bool settle = true,
  }) async {
    pushedRoute = null;
    launchedQuiz = null;
    await tester.runAsync(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      repo = _ObservedDetailRepository(
        db,
        canonicalRemote ?? importRemote ?? FakeRemote(),
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
      if (!seedWords) return;
      await repo.addConceptWithVariants(
        listId: listId,
        wordA: wordA,
        wordB: wordB,
        langA: langA,
        langB: langB,
      );
      if (extraWords > 0) {
        await db.transaction(() async {
          for (var i = 0; i < extraWords; i++) {
            // Spread the same two languages over many real stored concepts.
            await repo.addConceptWithVariants(
              listId: listId,
              wordA: 'sample A $i',
              wordB: 'sample B $i',
              langA: langA,
              langB: langB,
            );
          }
        });
      }
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
    auth = _DetailAuthRepository();
    addTearDown(auth.close);
    final overrides = [
      authRepositoryProvider.overrideWithValue(auth),
      vocabularyRepositoryProvider.overrideWith(
        (ref) => ref.watch(activeRepository) ?? repo,
      ),
      if (metadata != null)
        listInfoProvider.overrideWith((ref, _) => metadata()),
      isPremiumProvider.overrideWithValue(premium),
      if (assistant != null)
        vocabAssistantProvider.overrideWithValue(assistant),
    ];
    final routes = [
      GoRoute(
        path: '/paywall',
        pageBuilder: (_, state) {
          pushedRoute = '/paywall';
          return const MaterialPage<void>(
            child: Scaffold(
              key: ValueKey(WidgetKeys.screenPaywall),
              body: SizedBox(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/quiz',
        pageBuilder: (_, state) {
          launchedQuiz = state.extra! as QuizArgs;
          return const MaterialPage<void>(child: Scaffold(body: SizedBox()));
        },
      ),
    ];
    if (importRemote == null) {
      await pumpScreen(
        tester,
        screen: ListDetailScreen(listId: listId),
        themeMode: themeMode,
        settle: settle,
        overrides: overrides,
        routes: routes,
      );
      // Initialize the restored auth identity before an AI form can capture it.
      ProviderScope.containerOf(
        tester.element(find.byType(ListDetailScreen)),
      ).read(authStateProvider);
      await tester.pump();
      return;
    }
    final router = detailRouter = GoRouter(
      initialLocation: '/lists/$listId',
      routes: [
        ShellRoute(
          builder: (_, _, child) => ShellRouteVisibility(child: child),
          routes: [
            GoRoute(
              path: '/lists/:listId',
              builder: (_, state) =>
                  ListDetailScreen(listId: state.pathParameters['listId']!),
            ),
            ...routes,
          ],
        ),
        GoRoute(
          path: '/import',
          builder: (_, state) =>
              ImportFromLinkScreen(token: state.uri.queryParameters['token']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
        ),
      ),
    );
    await tester.pumpAndSettle();
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

  Finder byKey(String key, {bool skipOffstage = true}) =>
      find.byKey(ValueKey(key), skipOffstage: skipOffstage);

  Future<void> enterEditMode(WidgetTester tester) async {
    await tester.tap(byKey(WidgetKeys.listDetailMenu));
    await tester.pumpAndSettle();
    await tester.tap(byKey(WidgetKeys.listDetailEditItem));
    await tester.pumpAndSettle();
  }

  Future<void> openAiSheet(WidgetTester tester) async {
    await tester.tap(byKey(WidgetKeys.listDetailMenu));
    await tester.pumpAndSettle();
    await tester.tap(byKey(WidgetKeys.listDetailAiSuggestItem));
    await tester.pumpAndSettle();
  }

  Future<List<String>> storedWords(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final concepts = await db.conceptDao.getConceptsByList(listId);
        return [
          for (final concept in concepts)
            for (final variant in await db.conceptDao.getVariantsByConcept(
              concept.id,
            ))
              variant.word,
        ];
      }))!;

  Future<void> rejectWordWrites(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final operation in ['INSERT', 'UPDATE']) {
        await db.customStatement('''
          CREATE TRIGGER fail_word_$operation BEFORE $operation ON word_variants
          BEGIN SELECT RAISE(ABORT, 'test: word write failed'); END;
        ''');
      }
    });
  }

  testWidgets('manual Add avoids observing offscreen words in a large list', (
    tester,
  ) async {
    final assistant = _PairAssistant();
    await pump(tester, extraWords: 998, assistant: assistant);
    final visibleObservations = repo.variantObservations;
    expect(visibleObservations, inInclusiveRange(1, 30));

    await tester.tap(byKey(WidgetKeys.listDetailAddWord));
    await tester.pumpAndSettle();
    expect(byKey(WidgetKeys.addWordFr), findsOneWidget);
    expect(repo.variantObservations, visibleObservations);
    expect(repo.sampleLimits, isEmpty);
    expect(assistant.translatedWord, isNull);

    await tester.enterText(byKey(WidgetKeys.addWordKo), '단어');
    await tester.tap(byKey(WidgetKeys.addWordAiSuggest));
    await tester.pumpAndSettle();
    expect(assistant.translatedWord, '단어');
    expect((assistant.source, assistant.target), ('ko', 'fr'));
    expect(repo.sampleLimits, [VocabAssistantDataSource.maxContextItems]);
    expect(
      assistant.contextWords,
      hasLength(VocabAssistantDataSource.maxContextItems),
    );
    expect(
      assistant.contextWords.where((word) => word.startsWith('sample A')),
      isEmpty,
    );
    expect(
      assistant.contextWords.where((word) => word.startsWith('sample B')),
      isNotEmpty,
    );
    expect(repo.variantObservations, visibleObservations);
    await unmountScreen(tester);
  });

  for (final interruption in [
    'changed pair',
    'same account reconnected',
    'cancelled form',
  ]) {
    testWidgets(
      'Add translation discards pending context after $interruption',
      (tester) async {
        final assistant = _PairAssistant();
        await pump(tester, assistant: assistant);
        final gate = repo.sampleGate = Completer<void>();
        await tester.tap(byKey(WidgetKeys.listDetailAddWord));
        await tester.pumpAndSettle();
        await tester.enterText(byKey(WidgetKeys.addWordFr), 'chat');
        await tester.tap(byKey(WidgetKeys.addWordAiSuggest));
        await tester.pump();
        expect(repo.sampleLimits, hasLength(1));
        expect(assistant.translatedWord, isNull);

        switch (interruption) {
          case 'changed pair':
            await tester.runAsync(() async {
              final list = (await repo.getListById(listId)).valueOrNull!;
              expect(
                (await repo.updateList(list.copyWith(langA: 'en'))).isSuccess,
                isTrue,
              );
            });
          case 'same account reconnected':
            auth.switchAccount(null);
            auth.switchAccount('u');
          case 'cancelled form':
            await tester.tap(
              find.widgetWithText(TextButton, 'common.cancel'.tr()),
            );
            await tester.pump();
        }
        gate.complete();
        await tester.pumpAndSettle();

        expect(assistant.translatedWord, isNull);
        if (interruption == 'cancelled form') {
          expect(byKey(WidgetKeys.addWordFr), findsNothing);
        } else {
          expect(
            find.text('list_detail.word_pair_changed'.tr()),
            findsOneWidget,
          );
          expect(
            tester
                .widget<TextFormField>(byKey(WidgetKeys.addWordFr))
                .controller!
                .text,
            'chat',
          );
        }
        await unmountScreen(tester);
      },
    );
  }

  for (final mode in ['Add', 'Edit', 'themed suggestions']) {
    for (final fails in [false, true]) {
      testWidgets(
        '$mode ${fails ? 'failure' : 'success'} waits for the covering import',
        (tester) async {
          final remote = _PendingImportRemote();
          await pump(
            tester,
            importRemote: remote,
            assistant: _PairAssistant(
              pairs: const [
                WordPairSuggestion(source: 'saved source', target: '저장'),
              ],
            ),
          );
          final themed = mode == 'themed suggestions';
          final edit = mode == 'Edit';
          final saveKey = themed
              ? WidgetKeys.listDetailAiAddSelected
              : edit
              ? WidgetKeys.editWordConfirm
              : WidgetKeys.addWordConfirm;
          final save = byKey(saveKey);
          if (themed) {
            await openAiSheet(tester);
          } else {
            if (edit) await enterEditMode(tester);
            await tester.tap(
              byKey(
                edit
                    ? WidgetKeys.conceptEditIcon('chat')
                    : WidgetKeys.listDetailAddWord,
              ),
            );
            await tester.pumpAndSettle();
            await tester.enterText(
              byKey(edit ? WidgetKeys.editWordFr : WidgetKeys.addWordFr),
              'saved source',
            );
            await tester.enterText(
              byKey(edit ? WidgetKeys.editWordKo : WidgetKeys.addWordKo),
              '저장',
            );
          }
          if (fails) await rejectWordWrites(tester);
          final gate = repo.saveGate = Completer<void>();
          await tester.tap(save);
          await tester.pump();
          expect(repo.saveFinished, isTrue);
          final words = await storedWords(tester);
          expect(words.contains('saved source'), !fails);
          expect(words.contains('저장'), !fails);
          expect(words.contains('chat'), fails || !edit);

          unawaited(detailRouter!.push<void>('/import?token=covering'));
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(byKey(WidgetKeys.screenImport), findsOneWidget);
          expect(remote.requestedToken, 'covering');
          gate.complete();
          await tester.pump(const Duration(milliseconds: 400));
          expect(byKey(WidgetKeys.screenImport), findsOneWidget);
          final hiddenSave = byKey(saveKey, skipOffstage: false);
          expect(tester.widget<FilledButton>(hiddenSave).onPressed, isNull);

          final importSucceeds = mode == 'Add' && !fails;
          remote.reply.complete(
            Success(
              importSucceeds
                  ? {'name': 'Imported covering list', 'concepts': <Object>[]}
                  : null,
            ),
          );
          await tester.pumpAndSettle();
          expect(byKey(WidgetKeys.screenImport), findsNothing);
          if (importSucceeds) {
            expect(find.text('Imported covering list'), findsOneWidget);
            await tester.tap(byKey(WidgetKeys.listDetailBack));
            await tester.pumpAndSettle();
          }
          if (fails) {
            expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
            expect(
              find.text(
                (themed ? 'list_detail.ai_add_error' : 'common.error').tr(),
              ),
              findsOneWidget,
            );
            if (themed) {
              expect(
                tester
                    .widget<CheckboxListTile>(find.byType(CheckboxListTile))
                    .value,
                isTrue,
              );
            } else {
              final field = byKey(
                edit ? WidgetKeys.editWordFr : WidgetKeys.addWordFr,
              );
              expect(
                tester.widget<TextFormField>(field).controller!.text,
                'saved source',
              );
            }
          } else {
            expect(save, findsNothing);
            expect(find.text('saved source'), findsOneWidget);
          }
          expect(byKey(WidgetKeys.screenListDetail), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmountScreen(tester);
        },
      );
    }
  }

  for (final fails in [false, true]) {
    testWidgets(
      'Add blocks both suggestion types until save ${fails ? 'fails' : 'succeeds'}',
      (tester) async {
        await pump(tester, assistant: _PairAssistant());
        await tester.tap(byKey(WidgetKeys.listDetailAddWord));
        await tester.pumpAndSettle();
        final first = byKey(WidgetKeys.addWordFr);
        final second = byKey(WidgetKeys.addWordKo);
        await tester.enterText(first, 'chat');
        await tester.tap(byKey(WidgetKeys.addWordAiSuggest));
        await tester.pumpAndSettle();
        final chips = find.byType(ActionChip);
        expect(chips, findsNWidgets(2));
        for (final chip in tester.widgetList<ActionChip>(chips)) {
          expect(chip.onPressed, isNotNull);
        }
        await tester.enterText(first, 'submitted source');
        await tester.enterText(second, '제출');
        if (fails) await rejectWordWrites(tester);
        final gate = repo.saveGate = Completer<void>();
        await tester.tap(byKey(WidgetKeys.addWordConfirm));
        await tester.pumpAndSettle();

        expect(repo.saveFinished, isTrue);
        for (var i = 0; i < 2; i++) {
          expect(tester.widget<ActionChip>(chips.at(i)).onPressed, isNull);
          await tester.tap(chips.at(i), warnIfMissed: false);
        }
        expect(
          tester.widget<TextFormField>(first).controller!.text,
          'submitted source',
        );
        expect(tester.widget<TextFormField>(second).controller!.text, '제출');
        gate.complete();
        await tester.pumpAndSettle();
        final words = await storedWords(tester);
        expect(words.contains('submitted source'), !fails);
        expect(words.contains('제출'), !fails);
        expect(words, isNot(contains('le chat')));
        expect(words, isNot(contains('고양이 한 마리')));
        if (fails) {
          expect(find.text('common.error'.tr()), findsOneWidget);
          expect(
            tester.widget<TextFormField>(first).controller!.text,
            'submitted source',
          );
          expect(tester.widget<TextFormField>(second).controller!.text, '제출');
          for (final chip in tester.widgetList<ActionChip>(chips)) {
            expect(chip.onPressed, isNotNull);
          }
          await tester.tap(chips.last);
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextFormField>(first).controller!.text,
            'le chat',
          );
          expect(
            tester.widget<TextFormField>(second).controller!.text,
            '고양이 한 마리',
          );
        } else {
          expect(first, findsNothing);
        }
        await unmountScreen(tester);
      },
    );
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

  for (final (locale, editLabel, deleteLabel, emptyPreview) in [
    (
      'fr',
      'Modifier « chat »',
      'Supprimer « chat »',
      'Ajoute des paires de mots pour commencer à étudier.',
    ),
    ('en', 'Edit “chat”', 'Delete “chat”', 'Add word pairs to start studying.'),
    ('ko', '‘chat’ 편집', '‘chat’ 삭제', '학습을 시작하려면 단어 쌍을 추가하세요.'),
  ]) {
    Future<void> loadLocale(WidgetTester tester) async {
      final raw = await tester.runAsync(
        () => rootBundle.loadString('assets/translations/$locale.json'),
      );
      final translations = Translations(
        jsonDecode(raw!) as Map<String, dynamic>,
      );
      Localization.load(
        Locale(locale),
        translations: translations,
        fallbackTranslations: translations,
      );
      addTearDown(initTestLocalization);
    }

    testWidgets(
      'word row edit and delete are usable by keyboard in $locale',
      (tester) async {
        await loadLocale(tester);
        await pump(tester);
        await enterEditMode(tester);
        final edit = byKey(WidgetKeys.conceptEditIcon('chat'));
        final delete = byKey(WidgetKeys.conceptDeleteIcon('chat'));
        for (final (button, label) in [
          (edit, editLabel),
          (delete, deleteLabel),
        ]) {
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(
            tester.getSemantics(button),
            matchesSemantics(
              tooltip: label,
              isButton: true,
              hasTapAction: true,
              isEnabled: true,
              hasEnabledState: true,
              isFocusable: true,
              hasFocusAction: true,
            ),
          );
        }

        Future<void> activate(Finder button) async {
          bool containsFocus() {
            final element = tester.element(button);
            var focusedInside = false;
            FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
              ancestor,
            ) {
              focusedInside = ancestor == element;
              return !focusedInside;
            });
            return focusedInside;
          }

          for (var tabs = 0; tabs < 20 && !containsFocus(); tabs++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
          }
          expect(containsFocus(), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
        }

        await activate(edit);
        final field = byKey(WidgetKeys.editWordFr);
        expect(tester.widget<TextFormField>(field).controller!.text, 'chat');
        await tester.tap(find.widgetWithText(TextButton, 'common.cancel'.tr()));
        await tester.pumpAndSettle();
        await activate(delete);
        await tester.tap(byKey(WidgetKeys.deleteWordConfirm));
        await tester.pumpAndSettle();
        expect(await storedWords(tester), unorderedEquals(['chien', '개']));
        await unmountScreen(tester);
      },
      semanticsEnabled: true,
    );

    testWidgets('empty preview asks for words in $locale', (tester) async {
      await loadLocale(tester);
      await pump(tester, seedWords: false);
      final list = (await tester.runAsync(
        () => repo.getListById(listId),
      ))!.valueOrNull!;
      final context = tester.element(byKey(WidgetKeys.screenListDetail));
      unawaited(showListPreviewSheet(context, list));
      await tester.pumpAndSettle();

      final preview = find.byType(BottomSheet);
      expect(
        find.descendant(of: preview, matching: find.text(list.name)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.text(emptyPreview)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: preview,
          matching: find.text('start_session.empty_lists'.tr()),
        ),
        findsNothing,
      );
      await unmountScreen(tester);
    });
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

  testWidgets(
    'partial suggestions keep refused selections through upgrade and back',
    (tester) async {
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
        importRemote: _PendingImportRemote(),
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
      expect(byKey(WidgetKeys.screenPaywall), findsOneWidget);
      expect(byKey(WidgetKeys.listDetailAiAddSelected), findsNothing);
      detailRouter!.pop();
      await tester.pumpAndSettle();
      expect(byKey(WidgetKeys.screenPaywall), findsNothing);
      final resumedSelection = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(resumedSelection[0].onChanged, isNull);
      expect(resumedSelection[1].value, isTrue);
      expect(resumedSelection[1].onChanged, isNotNull);
      await unmountScreen(tester);
    },
  );

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
