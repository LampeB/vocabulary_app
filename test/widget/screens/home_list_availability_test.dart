import 'dart:async';
import 'dart:convert';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/screens/home/daily_path_screen.dart';
import 'package:vocab_kr/presentation/screens/home/v3_home_screen.dart';

import '../../helpers/pump_screen.dart';

void main() {
  setUpAll(initTestLocalization);

  for (final home in [true, false]) {
    testWidgets(
      '${home ? 'Home' : 'Daily Path'} keeps due reviews usable without lists',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        QuizArgs? started;
        await pumpScreen(
          tester,
          screen: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: home ? const V3HomeScreen() : const DailyPathScreen(),
          ),
          overrides: [
            currentUserProvider.overrideWithValue(null),
            myListsProvider.overrideWith(
              (ref) => Stream.error(StateError('lists unavailable')),
            ),
            dueCountForPairProvider.overrideWith(
              (ref, pair) => Stream.value(3),
            ),
            ruleStatusesProvider.overrideWith((ref, lang) async => []),
          ],
          routes: [
            GoRoute(
              path: '/daily-path',
              builder: (_, _) => const DailyPathScreen(),
            ),
            GoRoute(
              path: '/quiz',
              builder: (_, state) {
                started = state.extra as QuizArgs;
                return const Scaffold();
              },
            ),
          ],
        );
        if (home) {
          await tester.tap(
            find.byKey(const ValueKey(WidgetKeys.homeDailyPath)),
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.byKey(const ValueKey(WidgetKeys.dailyPathReview)),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey(WidgetKeys.homeReviewMode('typing'))),
        );
        await tester.pumpAndSettle();
        expect(started?.mode, QuizMode.typing);
        expect(started?.langA, 'fr');
        expect(started?.langB, 'ko');
        expect(tester.takeException(), isNull);
        await unmountScreen(tester);
      },
    );
  }

  for (final locale in ['fr', 'en', 'ko']) {
    for (final home in [true, false]) {
      testWidgets(
        '${home ? 'Home' : 'Daily Path'} list failure is not empty in $locale',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final copy =
              jsonDecode(
                    (await tester.runAsync(
                      () => rootBundle.loadString(
                        'assets/translations/$locale.json',
                      ),
                    ))!,
                  )
                  as Map<String, dynamic>;
          final translations = Translations(copy);
          Localization.load(
            Locale(locale),
            translations: translations,
            fallbackTranslations: translations,
          );
          addTearDown(initTestLocalization);
          final streams = <StreamController<List<VocabularyList>>>[];
          await pumpScreen(
            tester,
            screen: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: home ? const V3HomeScreen() : const DailyPathScreen(),
            ),
            overrides: [
              currentUserProvider.overrideWithValue(null),
              myListsProvider.overrideWith((ref) {
                final controller = StreamController<List<VocabularyList>>();
                streams.add(controller);
                ref.onDispose(controller.close);
                return controller.stream;
              }),
              dueCountForPairProvider.overrideWith(
                (ref, pair) => Stream.value(0),
              ),
              ruleStatusesProvider.overrideWith((ref, lang) async => []),
            ],
            routes: [
              for (final path in ['/lists', '/grammar'])
                GoRoute(
                  path: path,
                  builder: (_, _) => Scaffold(key: ValueKey(path)),
                ),
            ],
          );
          final loading = find.text(copy['v3.lists_loading'] as String);
          final error = find.text(copy['v3.lists_error'] as String);
          final prepare = find.text(copy['v3.prepare_list'] as String);
          final first = find.text(copy['v3.first_list'] as String);
          final retry = find.byKey(const ValueKey(WidgetKeys.homeListsRetry));
          expect(loading, findsWidgets);
          expect(prepare, findsNothing);
          expect(first, findsNothing);
          if (home) expect(find.text('—'), findsNWidgets(2));

          streams.single.addError(StateError('local list read unavailable'));
          await tester.pumpAndSettle();
          expect(error, findsWidgets);
          expect(retry, findsOneWidget);
          expect(prepare, findsNothing);
          expect(first, findsNothing);
          if (home) {
            expect(find.text('—'), findsNWidgets(2));
            // The course sheet also must not assert that no list exists.
            final entry = find.byKey(const ValueKey(WidgetKeys.homeGrammar));
            await tester.ensureVisible(entry);
            await tester.tap(entry);
            await tester.pumpAndSettle();
            expect(find.text(copy['v3.create_list'] as String), findsNothing);
            final lessons = find.text(copy['v3.see_lessons'] as String);
            await tester.tap(lessons);
            await tester.pumpAndSettle();
            final destination = find.byKey(const ValueKey('/grammar'));
            expect(destination, findsOneWidget);
            GoRouter.of(tester.element(destination)).pop();
            await tester.pumpAndSettle();
          } else {
            for (final (key, path) in [
              (WidgetKeys.dailyPathPractice, '/lists'),
              (WidgetKeys.dailyPathLessons, '/grammar'),
            ]) {
              final entry = find.byKey(ValueKey(key));
              await tester.ensureVisible(entry);
              await tester.tap(entry);
              await tester.pumpAndSettle();
              final destination = find.byKey(ValueKey(path));
              expect(destination, findsOneWidget);
              GoRouter.of(tester.element(destination)).pop();
              await tester.pumpAndSettle();
            }
          }

          await tester.ensureVisible(retry);
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(streams, hasLength(2));
          expect(loading, findsWidgets);
          expect(prepare, findsNothing);
          streams.last.add([]);
          await tester.pumpAndSettle();
          expect(prepare, findsOneWidget);
          expect(retry, findsNothing);
          if (home) expect(find.text('—'), findsNothing);

          final now = DateTime(2026);
          streams.last.add([
            VocabularyList(
              id: 'other',
              ownerId: 'u',
              name: 'Other pair',
              langA: 'en',
              langB: 'ko',
              wordCount: 19,
              createdAt: now,
              updatedAt: now,
            ),
            VocabularyList(
              id: 'mine',
              ownerId: 'u',
              name: 'Existing list',
              wordCount: 7,
              createdAt: now,
              updatedAt: now,
            ),
          ]);
          await tester.pumpAndSettle();
          expect(prepare, findsNothing);
          expect(find.text('Existing list'), findsWidgets);
          expect(find.text('Other pair'), findsNothing);
          if (home) expect(find.text('7'), findsOneWidget);

          // A later failure cannot keep an old success as current evidence.
          streams.last.addError(StateError('failed after data'));
          await tester.pumpAndSettle();
          expect(error, findsWidgets);
          expect(find.text('Existing list'), findsNothing);
          expect(prepare, findsNothing);
          expect(retry, findsOneWidget);
          if (home) expect(find.text('—'), findsNWidgets(2));
          expect(tester.takeException(), isNull);
          await unmountScreen(tester);
        },
      );
    }
  }
}
