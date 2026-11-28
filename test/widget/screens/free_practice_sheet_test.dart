import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/languages.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';
import 'package:vocab_kr/data/datasources/local/daos/progress_dao.dart';
import 'package:vocab_kr/data/repositories/vocabulary_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/domain/entities/variant_progress.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_availability_provider.dart';
import 'package:vocab_kr/domain/entities/concept.dart';
import 'package:vocab_kr/domain/entities/word_variant.dart';
import 'package:vocab_kr/presentation/widgets/free_practice_sheet.dart';
import '../../helpers/pump_screen.dart';
import '../../helpers/fake_remote.dart';

class _AvailabilityDao implements ProgressDao {
  final dueRequests = <(String, String, String, List<QuizDirection>)>[];
  final dueStreams = <StreamController<int>>[];
  var inProgressRequests = 0;

  @override
  Stream<int> watchSmartQuizCardCount({
    required String userId,
    required List<QuizDirection> directions,
    required SmartQuizPool pool,
    required String langA,
    required String langB,
    Duration refreshEvery = const Duration(minutes: 1),
  }) {
    if (pool == SmartQuizPool.inProgress) {
      inProgressRequests++;
      return Stream.value(3);
    }
    dueRequests.add((userId, langA, langB, directions));
    final stream = StreamController<int>();
    dueStreams.add(stream);
    return stream.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final copies = <String, Map<String, dynamic>>{};
  setUpAll(() async {
    await initTestLocalization();
    for (final locale in ['fr', 'en', 'ko']) {
      copies[locale] =
          jsonDecode(
                await rootBundle.loadString('assets/translations/$locale.json'),
              )
              as Map<String, dynamic>;
    }
  });

  for (final locale in ['fr', 'en', 'ko']) {
    testWidgets(
      'one real concept in both directions launches two cards in $locale',
      (tester) async {
        final translations = Translations(copies[locale]!);
        Localization.load(
          Locale(locale),
          translations: translations,
          fallbackTranslations: translations,
        );
        addTearDown(initTestLocalization);
        late AppDatabase db;
        late VocabularyRepositoryImpl repo;
        late String listId;
        await tester.runAsync(() async {
          db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);
          repo = VocabularyRepositoryImpl(
            db.vocabularyListDao,
            db.conceptDao,
            FakeRemote(),
            'u',
            db,
          );
          final list = (await repo.createList(
            name: 'Single concept',
            langA: 'en',
            langB: 'ko',
          )).valueOrNull!;
          listId = list.id;
          await repo.addConceptWithVariants(
            listId: listId,
            wordA: 'cat',
            wordB: '고양이',
            langA: 'en',
            langB: 'ko',
          );
        });
        QuizArgs? args;
        await pumpScreen(
          tester,
          screen: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showFreePracticeSheet(context, pair: ('en', 'ko')),
                child: const Text('Open'),
              ),
            ),
          ),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vocabularyRepositoryProvider.overrideWithValue(repo),
            currentUserProvider.overrideWithValue(
              AppUser(
                id: 'u',
                email: 'u@example.test',
                username: 'u',
                createdAt: DateTime(2026),
              ),
            ),
          ],
          routes: [
            GoRoute(
              path: '/quiz',
              builder: (_, state) {
                args = state.extra! as QuizArgs;
                return const Scaffold();
              },
            ),
          ],
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final option = find.byKey(ValueKey('free-practice-list-$listId'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        final start = find.byKey(const ValueKey('free-practice-start'));
        final label =
            (copies[locale]!['start_session.start_with_count'] as String)
                .replaceAll('{count}', '2');
        expect(
          find.descendant(of: start, matching: find.text(label)),
          findsOneWidget,
        );
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(args!.direction, QuizDirectionChoice.both);
        expect(args!.cardLimit, 2);
        expect(args!.listId, listId);
        expect(tester.takeException(), isNull);
        await unmountScreen(tester);
      },
    );
  }

  for (final locale in ['fr', 'en', 'ko']) {
    testWidgets(
      'a failed due count can be retried with another source selected in $locale',
      (tester) async {
        final copy = copies[locale]!;
        final translations = Translations(copy);
        Localization.load(
          Locale(locale),
          translations: translations,
          fallbackTranslations: translations,
        );
        addTearDown(initTestLocalization);
        final dao = _AvailabilityDao();
        QuizArgs? args;
        await pumpScreen(
          tester,
          screen: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showFreePracticeSheet(context, pair: ('en', 'ko')),
                child: const Text('Open'),
              ),
            ),
          ),
          overrides: [
            myListsProvider.overrideWith((ref) => Stream.value([])),
            studiedListIdsProvider.overrideWith((ref) => Stream.value({})),
            currentUserProvider.overrideWithValue(
              AppUser(
                id: 'u',
                email: 'u@example.test',
                username: 'u',
                createdAt: DateTime(2026),
              ),
            ),
            progressDaoProvider.overrideWithValue(dao),
          ],
          routes: [
            GoRoute(
              path: '/quiz',
              builder: (_, state) {
                args = state.extra! as QuizArgs;
                return const Scaffold();
              },
            ),
          ],
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final due = find.byKey(const ValueKey('free-practice-due'));
        final start = find.byKey(const ValueKey('free-practice-start'));
        final retry = find.byKey(const ValueKey(WidgetKeys.reviewDueRetry));
        final empty = find.text(copy['quiz.no_cards_available'] as String);
        final loading = find.text(copy['v3.review_due_loading'] as String);
        final error = find.text(copy['v3.review_due_error'] as String);
        final dueTitle = copy['start_session.smart_due'] as String;
        String? label() => (tester.widget<ChoiceChip>(due).label as Text).data;
        bool canStart() => tester.widget<FilledButton>(start).onPressed != null;
        expect(label(), dueTitle);
        expect(loading, findsOneWidget);
        expect(empty, findsNothing);
        expect(retry, findsNothing);
        expect(canStart(), isFalse);
        expect(
          find.descendant(
            of: start,
            matching: find.text(copy['start_session.start'] as String),
          ),
          findsOneWidget,
        );

        dao.dueStreams.single.add(0);
        await tester.pumpAndSettle();
        expect(label(), '$dueTitle · 0');
        expect(empty, findsOneWidget);
        expect(canStart(), isFalse);

        dao.dueStreams.single.addError(
          StateError('controlled due read failure'),
        );
        await tester.pumpAndSettle();
        expect(label(), dueTitle);
        expect(error, findsOneWidget);
        expect(empty, findsNothing);
        expect(canStart(), isFalse);

        final other = find.byKey(const ValueKey('free-practice-in-progress'));
        await tester.ensureVisible(other);
        await tester.tap(other);
        await tester.pumpAndSettle();
        expect(error, findsOneWidget);
        expect(label(), dueTitle);
        expect(canStart(), isTrue);
        expect(
          find.descendant(
            of: retry,
            matching: find.text(copy['common.retry'] as String),
          ),
          findsOneWidget,
        );

        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(dao.dueRequests, hasLength(2));
        for (final (user, base, target, directions) in dao.dueRequests) {
          expect((user, base, target), ('u', 'en', 'ko'));
          expect(directions, [
            const QuizDirection(questionLang: 'en', answerLang: 'ko'),
            const QuizDirection(questionLang: 'ko', answerLang: 'en'),
          ]);
        }
        expect(dao.inProgressRequests, 1);
        expect(label(), dueTitle);
        expect(loading, findsOneWidget);
        expect(canStart(), isTrue);

        dao.dueStreams.last.add(2);
        await tester.pumpAndSettle();
        expect(label(), '$dueTitle · 2');
        expect(retry, findsNothing);
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(args?.source, QuizSource.inProgress);
        expect(args?.cardLimit, 3);
        await unmountScreen(tester);
        for (final stream in dao.dueStreams) {
          unawaited(stream.close());
        }
      },
    );
  }

  testWidgets(
    'empty direction and a new account in-progress pool cannot start',
    (tester) async {
      await pumpScreen(
        tester,
        screen: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showFreePracticeSheet(context, pair: ('en', 'ko')),
              child: const Text('Open'),
            ),
          ),
        ),
        overrides: [
          myListsProvider.overrideWith((ref) => Stream.value([])),
          studiedListIdsProvider.overrideWith((ref) => Stream.value({})),
          quizAvailabilityProvider.overrideWith(
            (ref, q) => Stream.value(
              q.source == QuizSource.allDue &&
                      q.direction != QuizDirectionChoice.frToKo
                  ? 3
                  : 0,
            ),
          ),
        ],
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final start = find.byKey(const ValueKey('free-practice-start'));
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      await tester.tap(
        find.byKey(const ValueKey('free-practice-direction-frToKo')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      expect(
        find.text('Aucune carte n’est disponible pour cette sélection.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('free-practice-in-progress')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      await unmountScreen(tester);
    },
  );

  testWidgets('a long preview title and its words share a signalled scroller', (
    tester,
  ) async {
    final now = DateTime(2026);
    final list = VocabularyList(
      id: 'long',
      ownerId: 'u',
      name: List.filled(10, 'Salutations utiles en voyage').join(' '),
      wordCount: 1,
      langA: 'en',
      langB: 'ko',
      createdAt: now,
      updatedAt: now,
    );
    await pumpScreen(
      tester,
      screen: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showFreePracticeSheet(context, pair: ('en', 'ko')),
            child: const Text('Open'),
          ),
        ),
      ),
      overrides: [
        myListsProvider.overrideWith((ref) => Stream.value([list])),
        studiedListIdsProvider.overrideWith((ref) => Stream.value({})),
        quizAvailabilityProvider.overrideWith((ref, q) => Stream.value(0)),
        listDetailProvider.overrideWith(
          (ref, id) => Stream.value([
            Concept(id: 'c', listId: 'long', createdAt: now, updatedAt: now),
          ]),
        ),
        variantsProvider.overrideWith(
          (ref, id) => Stream.value([
            WordVariant(
              id: 'en',
              conceptId: 'c',
              word: 'hello',
              langCode: 'en',
              createdAt: now,
              updatedAt: now,
            ),
            WordVariant(
              id: 'ko',
              conceptId: 'c',
              word: '안녕',
              langCode: 'ko',
              createdAt: now,
              updatedAt: now,
            ),
          ]),
        ),
      ],
    );
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final preview = find.byTooltip('Aperçu');
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(find.byType(CustomScrollView), findsOneWidget);
    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    for (var i = 0; i < 3; i++) {
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();
    expect(find.text('hello').hitTestable(), findsOneWidget);
    expect(find.text('안녕').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmountScreen(tester);
  });
  for (final pair in [('fr', 'ko'), ('en', 'ko'), ('ko', 'fr')]) {
    testWidgets('sheet launches both directions in $pair without full setup', (
      tester,
    ) async {
      QuizArgs? args;
      await pumpScreen(
        tester,
        screen: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showFreePracticeSheet(context, pair: pair),
              child: const Text('Open'),
            ),
          ),
        ),
        overrides: [
          myListsProvider.overrideWith((ref) => Stream.value([])),
          studiedListIdsProvider.overrideWith((ref) => Stream.value({})),
          quizAvailabilityProvider.overrideWith(
            (ref, q) => Stream.value(q.pair == pair ? 24 : 0),
          ),
          dueCountForPairProvider.overrideWith(
            (ref, p) => Stream.value(p == pair ? 24 : 0),
          ),
        ],
        routes: [
          GoRoute(
            path: '/quiz',
            builder: (_, state) {
              args = state.extra! as QuizArgs;
              return const Scaffold(body: Text('Quiz'));
            },
          ),
        ],
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '${Languages.displayName(pair.$1)} → ${Languages.displayName(pair.$2)}',
        ),
        findsWidgets,
      );
      final start = find.byKey(const ValueKey('free-practice-start'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(args!.source, QuizSource.allDue);
      expect(args!.direction, QuizDirectionChoice.both);
      expect((args!.langA, args!.langB), pair);
      expect(args!.cardLimit, 20);
      expect(args!.distinctCardsOnly, isTrue);
    });
  }

  testWidgets(
    'an unstudied list is immediately playable with keyboard at double text',
    (tester) async {
      QuizArgs? args;
      final now = DateTime(2026);
      final list = VocabularyList(
        id: 'l',
        ownerId: 'u',
        name: 'Salutations',
        wordCount: 5,
        langA: 'en',
        langB: 'ko',
        createdAt: now,
        updatedAt: now,
      );
      await pumpScreen(
        tester,
        screen: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showFreePracticeSheet(context, pair: ('en', 'ko')),
              child: const Text('Open'),
            ),
          ),
        ),
        overrides: [
          myListsProvider.overrideWith((ref) => Stream.value([list])),
          studiedListIdsProvider.overrideWith((ref) => Stream.value({})),
          quizAvailabilityProvider.overrideWith(
            (ref, q) => Stream.value(q.source == QuizSource.list ? 5 : 0),
          ),
          dueCountForPairProvider.overrideWith((ref, p) => Stream.value(0)),
        ],
        routes: [
          GoRoute(
            path: '/quiz',
            builder: (_, state) {
              args = state.extra! as QuizArgs;
              return const Scaffold(body: Text('Quiz'));
            },
          ),
        ],
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final listChoice = find.byKey(const ValueKey('free-practice-list-l'));
      await tester.ensureVisible(listChoice);
      await tester.tap(listChoice);
      await tester.pumpAndSettle();
      final typing = find.byKey(const ValueKey('free-practice-mode-typing'));
      await tester.ensureVisible(typing);
      await tester.tap(typing);
      final start = find.byKey(const ValueKey('free-practice-start'));
      await tester.ensureVisible(start);
      Focus.of(
        tester.element(
          find.descendant(of: start, matching: find.byType(Text)).first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(args!.listId, 'l');
      expect(args!.mode, QuizMode.typing);
      expect(tester.takeException(), isNull);
    },
  );
}
