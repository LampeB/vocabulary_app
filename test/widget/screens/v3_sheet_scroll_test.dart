import 'dart:convert';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/languages.dart';
import 'package:vocab_kr/core/theme/app_theme.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/settings/default_pair_provider.dart';
import 'package:vocab_kr/presentation/screens/home/daily_path_screen.dart';
import 'package:vocab_kr/presentation/screens/home/v3_home_screen.dart';

import '../../helpers/pump_screen.dart';

void main() {
  for (final locale in ['fr', 'en', 'ko']) {
    for (final pairSheet in [true, false]) {
      testWidgets(
        '${pairSheet ? 'pair' : 'mode'} sheet announces overflow before a gesture in $locale',
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
          tester.view.physicalSize = const Size(568, 320);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var startedQuiz = false;
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) =>
                    pairSheet ? const V3HomeScreen() : const DailyPathScreen(),
              ),
              GoRoute(
                path: '/quiz',
                builder: (_, _) {
                  startedQuiz = true;
                  return const Scaffold();
                },
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                currentUserProvider.overrideWithValue(null),
                myListsProvider.overrideWith((ref) => Stream.value([])),
                dueCountForPairProvider.overrideWith(
                  (ref, pair) => Stream.value(3),
                ),
                ruleStatusesProvider.overrideWith((ref, lang) async => []),
              ],
              child: MaterialApp.router(
                theme: AppTheme.light,
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final opener = find.byKey(
            ValueKey(
              pairSheet
                  ? WidgetKeys.homePairPicker
                  : WidgetKeys.dailyPathReview,
            ),
          );
          await tester.ensureVisible(opener);
          await tester.tap(opener);
          await tester.pumpAndSettle();
          final cue = find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(copy['v3.scroll_hint'] as String),
          );
          expect(cue, findsOneWidget);
          final opacity = find
              .ancestor(of: cue, matching: find.byType(AnimatedOpacity))
              .first;
          expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
          // Only after observing the cue, scroll to an initially hidden option.
          final option = pairSheet
              ? find.textContaining(
                  '${Languages.displayName('ko')} → ${Languages.displayName('fr')}',
                )
              : find.byKey(ValueKey(WidgetKeys.homeReviewMode('flashcard')));
          await tester.ensureVisible(option);
          await tester.pumpAndSettle();
          await tester.tap(option);
          await tester.pumpAndSettle();
          if (pairSheet) {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(V3HomeScreen)),
            );
            expect(container.read(defaultPairProvider), ('ko', 'fr'));
          } else {
            expect(startedQuiz, isTrue);
          }
          expect(tester.takeException(), isNull);
          await unmountScreen(tester);
        },
      );
    }
  }
}
