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
import 'package:vocab_kr/core/theme/v3_colors.dart';
import 'package:vocab_kr/data/datasources/local/daos/progress_dao.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/presentation/providers/settings/default_pair_provider.dart';
import 'package:vocab_kr/presentation/widgets/session_bootstrap.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_availability_provider.dart';
import 'package:vocab_kr/presentation/screens/home/daily_path_screen.dart';
import 'package:vocab_kr/presentation/screens/home/v3_home_screen.dart';

import '../../helpers/pump_screen.dart';

class _ControlledDueQueries implements ProgressDao {
  final requests = <(String, String, String)>[];
  final streams = <StreamController<int>>[];

  @override
  Stream<int> watchDueCountForPair(
    String userId,
    String langA,
    String langB, {
    Duration refreshEvery = const Duration(minutes: 1),
  }) {
    requests.add((userId, langA, langB));
    final stream = StreamController<int>();
    streams.add(stream);
    return stream.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(initTestLocalization);

  testWidgets(
    'header switch keeps shared bootstrap subscribed to the new pair',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final seededPairs = <(String, String)>[];
      await pumpScreen(
        tester,
        settle: false,
        screen: const SessionBootstrap(child: V3HomeScreen()),
        overrides: [
          currentUserProvider.overrideWithValue(
            AppUser(
              id: 'u',
              email: 'u@example.test',
              username: 'u',
              subscriptionType: SubscriptionType.free,
              createdAt: DateTime(2026),
            ),
          ),
          myListsProvider.overrideWith((ref) => Stream.value([])),
          quizAvailabilityProvider.overrideWith((ref, q) => Stream.value(0)),
          dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(0)),
          ruleStatusesProvider.overrideWith((ref, lang) async => []),
          seedStarterListsProvider.overrideWith((ref) async {
            seededPairs.add(ref.watch(defaultPairProvider));
          }),
        ],
      );
      expect(seededPairs, [('fr', 'ko')]);
      await tester.tap(find.byKey(const ValueKey(WidgetKeys.homePairPicker)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(ValueKey(WidgetKeys.homePair('ko', 'fr'))));
      await tester.pump(const Duration(milliseconds: 400));
      expect(seededPairs, [('fr', 'ko'), ('ko', 'fr')]);
      await unmountScreen(tester);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('paper sheet titles remain readable in $mode', (tester) async {
      await pumpScreen(
        tester,
        screen: const V3HomeScreen(),
        settle: false,
        themeMode: mode,
        overrides: [
          currentUserProvider.overrideWithValue(null),
          myListsProvider.overrideWith((ref) => Stream.value([])),
          dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(0)),
          ruleStatusesProvider.overrideWith((ref, lang) async => []),
        ],
      );
      final sheets = [
        (
          find.byKey(const ValueKey(WidgetKeys.homePairPicker)),
          'Ta langue du moment',
        ),
        (find.byKey(const ValueKey(WidgetKeys.homeGrammar)), 'Mon parcours'),
        (find.text('Choisir une activité'), 'Pratique libre'),
      ];
      for (final (entry, title) in sheets) {
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pump(const Duration(milliseconds: 400));
        final titleFinder = find.text(title).last;
        expect(titleFinder, findsOneWidget);
        final text = tester.widget<Text>(titleFinder);
        final foreground = text.style!.color!;
        final background = title == 'Pratique libre'
            ? Theme.of(
                    tester.element(titleFinder),
                  ).bottomSheetTheme.backgroundColor ??
                  Theme.of(tester.element(titleFinder)).colorScheme.surface
            : V3Colors.paper2;
        final a = foreground.computeLuminance();
        final b = background.computeLuminance();
        expect(
          a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05),
          greaterThanOrEqualTo(4.5),
        );
        Navigator.of(tester.element(titleFinder)).pop();
        await tester.pump(const Duration(milliseconds: 400));
      }
      await unmountScreen(tester);
    });
  }

  for (final locale in ['fr', 'en', 'ko']) {
    testWidgets(
      'review counts fail and recover on Home and Daily Path in $locale',
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
        final dao = _ControlledDueQueries();
        await pumpScreen(
          tester,
          screen: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: const V3HomeScreen(),
            ),
          ),
          overrides: [
            currentUserProvider.overrideWithValue(
              AppUser(
                id: 'u',
                email: 'u@example.test',
                username: 'u',
                subscriptionType: SubscriptionType.free,
                createdAt: DateTime(2026),
              ),
            ),
            myListsProvider.overrideWith((ref) => Stream.value([])),
            ruleStatusesProvider.overrideWith((ref, lang) async => []),
            progressDaoProvider.overrideWithValue(dao),
          ],
          routes: [
            GoRoute(
              path: '/daily-path',
              builder: (_, _) => const DailyPathScreen(),
            ),
            for (final path in ['/lists', '/grammar'])
              GoRoute(
                path: path,
                builder: (_, _) => Scaffold(key: ValueKey(path)),
              ),
          ],
        );

        final loading = find.text(copy['v3.review_due_loading'] as String);
        final error = find.text(copy['v3.review_due_error'] as String);
        final noReviews = find.text(copy['v3.no_reviews_due'] as String);
        final reviewRetry = find.byKey(
          const ValueKey(WidgetKeys.reviewDueRetry),
        );
        final homeRecommendation = find.descendant(
          of: find.byKey(const ValueKey(WidgetKeys.homeDailyPath)),
          matching: find.text(copy['v3.prepare_list'] as String),
        );
        final homeZeroLabel = find.text(copy['v3.nothing_due'] as String);
        final firstList = find.text(copy['v3.first_list'] as String);

        expect(loading, findsOneWidget);
        expect(homeZeroLabel, findsNothing);
        expect(homeRecommendation, findsNothing);
        expect(dao.requests, [('u', 'fr', 'ko')]);
        dao.streams.single.addError(StateError('test read failure'));
        await tester.pumpAndSettle();
        expect(error, findsOneWidget);
        expect(reviewRetry, findsOneWidget);
        expect(find.text('—'), findsOneWidget);
        expect(homeZeroLabel, findsNothing);
        expect(homeRecommendation, findsNothing);

        await tester.tap(find.byKey(const ValueKey(WidgetKeys.homeDailyPath)));
        await tester.pumpAndSettle();
        expect(error, findsOneWidget);
        expect(noReviews, findsNothing);
        expect(firstList, findsNothing);
        expect(
          find.descendant(
            of: reviewRetry,
            matching: find.text(copy['common.retry'] as String),
          ),
          findsOneWidget,
        );
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
          expect(error, findsOneWidget);
        }

        await tester.ensureVisible(reviewRetry);
        await tester.tap(reviewRetry);
        await tester.pumpAndSettle();
        expect(dao.requests, List.filled(2, ('u', 'fr', 'ko')));
        expect(loading, findsOneWidget);
        expect(noReviews, findsNothing);
        dao.streams.last.add(0);
        await tester.pumpAndSettle();
        expect(noReviews, findsOneWidget);
        expect(firstList, findsOneWidget);

        // A stream can fail after emitting a previously valid zero.
        dao.streams.last.addError(StateError('test failure after zero'));
        await tester.pumpAndSettle();
        expect(error, findsOneWidget);
        expect(noReviews, findsNothing);
        expect(firstList, findsNothing);

        GoRouter.of(tester.element(find.byType(DailyPathScreen))).pop();
        await tester.pumpAndSettle();
        expect(homeZeroLabel, findsNothing);
        expect(homeRecommendation, findsNothing);
        await tester.tap(reviewRetry);
        await tester.pumpAndSettle();
        expect(dao.requests, List.filled(3, ('u', 'fr', 'ko')));
        expect(loading, findsOneWidget);
        expect(homeZeroLabel, findsNothing);
        dao.streams.last.add(3);
        await tester.pumpAndSettle();
        expect(
          find.text(
            (copy['v3.words_due'] as String).replaceFirst('{count}', '3'),
          ),
          findsWidgets,
        );
        expect(reviewRetry, findsNothing);
        await unmountScreen(tester);
        for (final stream in dao.streams) {
          unawaited(stream.close());
        }
      },
    );

    testWidgets('home actions remain reachable with large text in $locale', (
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

      await pumpScreen(
        tester,
        settle: false,
        screen: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: const V3HomeScreen(),
          ),
        ),
        overrides: [
          currentUserProvider.overrideWithValue(null),
          myListsProvider.overrideWith((ref) => Stream.value([])),
          dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(0)),
          ruleStatusesProvider.overrideWith((ref, lang) async => []),
        ],
      );
      tester.view.physicalSize = const Size(960, 1704);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey(WidgetKeys.homeGrammar)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await unmountScreen(tester);
    });
  }
}
