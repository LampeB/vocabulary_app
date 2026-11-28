import 'dart:convert';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/screens/home/daily_path_screen.dart';
import 'package:vocab_kr/presentation/screens/lists/lists_screen.dart';
import '../../helpers/pump_screen.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets('shows an optional daily plan and keeps free practice visible', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      screen: const DailyPathScreen(),
      overrides: [
        myListsProvider.overrideWith((ref) => Stream.value([])),
        dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(3)),
      ],
      routes: [
        GoRoute(path: '/grammar', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/lists', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/quiz', builder: (_, _) => const SizedBox()),
      ],
    );

    expect(
      find.byKey(const ValueKey(WidgetKeys.screenDailyPath)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey(WidgetKeys.dailyPathReview)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey(WidgetKeys.dailyPathLessons)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey(WidgetKeys.dailyPathPractice)),
      findsOneWidget,
    );
    expect(find.text('TES CARTES DU JOUR'), findsOneWidget);
  });

  testWidgets('passes the active pair into an all-due review session', (
    tester,
  ) async {
    QuizArgs? args;
    await pumpScreen(
      tester,
      screen: const DailyPathScreen(),
      overrides: [
        myListsProvider.overrideWith((ref) => Stream.value([])),
        dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(3)),
      ],
      routes: [
        GoRoute(
          path: '/quiz',
          builder: (_, state) {
            args = state.extra as QuizArgs;
            return const SizedBox();
          },
        ),
      ],
    );

    await tester.tap(find.byKey(const ValueKey(WidgetKeys.dailyPathReview)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(WidgetKeys.homeReviewMode('typing'))));
    await tester.pumpAndSettle();

    expect(args!.source, QuizSource.allDue);
    expect(args!.mode, QuizMode.typing);
    expect(args!.direction, QuizDirectionChoice.both);
    expect(args!.langA, 'fr');
    expect(args!.langB, 'ko');
  });

  testWidgets('no due cards do not imply a completed daily activity', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      screen: const DailyPathScreen(),
      overrides: [
        myListsProvider.overrideWith((ref) => Stream.value([])),
        dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(0)),
      ],
    );
    expect(find.text('Aucune révision à échéance'), findsOneWidget);
    expect(find.text('1 / 4'), findsNothing);
    expect(find.text('Révisions terminées'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  for (final fromActiveCard in [true, false]) {
    testWidgets('library Back returns to the daily path from '
        '${fromActiveCard ? 'the active card' : 'the discovery step'}', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        screen: const DailyPathScreen(),
        overrides: [
          myListsProvider.overrideWith((ref) => Stream.value([])),
          dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(0)),
        ],
        routes: [
          GoRoute(path: '/lists', builder: (_, _) => const ListsScreen()),
        ],
      );
      final entry = fromActiveCard
          ? find.text('Préparer une première liste')
          : find.byKey(const ValueKey(WidgetKeys.dailyPathPractice));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(ListsScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(DailyPathScreen), findsOneWidget);
      expect(find.byType(ListsScreen), findsNothing);
    });
  }

  for (final locale in ['fr', 'en', 'ko']) {
    testWidgets('small screen and large text keep the path usable in $locale', (
      tester,
    ) async {
      final translations = Translations(
        jsonDecode(
              (await tester.runAsync(
                () => rootBundle.loadString('assets/translations/$locale.json'),
              ))!,
            )
            as Map<String, dynamic>,
      );
      Localization.load(
        Locale(locale),
        translations: translations,
        fallbackTranslations: translations,
      );
      addTearDown(initTestLocalization);

      var openedLessons = false;
      await pumpScreen(
        tester,
        screen: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: const DailyPathScreen(),
          ),
        ),
        overrides: [
          myListsProvider.overrideWith((ref) => Stream.value([])),
          dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(3)),
        ],
        routes: [
          GoRoute(
            path: '/grammar',
            builder: (_, _) {
              openedLessons = true;
              return const SizedBox();
            },
          ),
        ],
      );
      tester.view.physicalSize = const Size(960, 1704); // 320 × 568
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The content may scroll but it must neither overlap nor truncate its
      // primary actions when the system text size is doubled.
      final lessons = find.byKey(const ValueKey(WidgetKeys.dailyPathLessons));
      await tester.ensureVisible(lessons);
      await tester.pumpAndSettle();
      await tester.tap(lessons);
      await tester.pumpAndSettle();
      expect(openedLessons, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
