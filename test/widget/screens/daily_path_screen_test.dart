import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/screens/home/daily_path_screen.dart';
import '../../helpers/pump_screen.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets('shows an optional daily plan and keeps free practice visible',
      (tester) async {
    await pumpScreen(
      tester,
      screen: const DailyPathScreen(),
      overrides: [
        dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(3)),
      ],
      routes: [
        GoRoute(path: '/grammar', builder: (_, __) => const SizedBox()),
        GoRoute(path: '/lists', builder: (_, __) => const SizedBox()),
        GoRoute(path: '/quiz', builder: (_, __) => const SizedBox()),
      ],
    );

    expect(
        find.byKey(const ValueKey(WidgetKeys.screenDailyPath)), findsOneWidget);
    expect(
        find.byKey(const ValueKey(WidgetKeys.dailyPathReview)), findsOneWidget);
    expect(find.byKey(const ValueKey(WidgetKeys.dailyPathLessons)),
        findsOneWidget);
    expect(find.byKey(const ValueKey(WidgetKeys.dailyPathPractice)),
        findsOneWidget);
    expect(find.text('daily_path.title'.tr()), findsOneWidget);
  });

  testWidgets('passes the active pair into an all-due review session',
      (tester) async {
    QuizArgs? args;
    await pumpScreen(
      tester,
      screen: const DailyPathScreen(),
      overrides: [
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

    await tester.tap(find.text('daily_path.review_open'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(WidgetKeys.homeReviewMode('typing'))));
    await tester.pumpAndSettle();

    expect(args!.source, QuizSource.allDue);
    expect(args!.mode, QuizMode.typing);
    expect(args!.direction, QuizDirectionChoice.both);
    expect(args!.langA, 'fr');
    expect(args!.langB, 'ko');
  });
}
