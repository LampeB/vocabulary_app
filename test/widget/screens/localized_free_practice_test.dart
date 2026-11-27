import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/core/ponderin_localization.dart';
import 'package:vocab_kr/core/theme/app_theme.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_availability_provider.dart';
import 'package:vocab_kr/presentation/screens/home/v3_home_screen.dart';
import 'package:vocab_kr/presentation/widgets/free_practice_sheet.dart';

void main() {
  testWidgets(
    'production locale config reads the plateau and sheet in Japanese with fallback',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final copy = (await tester.runAsync(() async {
        await EasyLocalization.ensureInitialized();
        final ja =
            jsonDecode(
                  await rootBundle.loadString('assets/translations/ja.json'),
                )
                as Map<String, dynamic>;
        final fr =
            jsonDecode(
                  await rootBundle.loadString('assets/translations/fr.json'),
                )
                as Map<String, dynamic>;
        return (ja, fr);
      }))!;
      final entry =
          (copy.$1['v3.choose_activity'] ?? copy.$2['v3.choose_activity'])
              as String;
      final title =
          (copy.$1['course.free_practice'] ?? copy.$2['course.free_practice'])
              as String;
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const V3HomeScreen())],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        PonderinLocalization(
          startLocale: const Locale('ja'),
          child: ProviderScope(
            overrides: [
              currentUserProvider.overrideWithValue(null),
              myListsProvider.overrideWith((ref) => Stream.value([])),
              studiedListIdsProvider.overrideWith((ref) => Stream.value({})),
              dueCountForPairProvider.overrideWith(
                (ref, pair) => Stream.value(0),
              ),
              quizAvailabilityProvider.overrideWith(
                (ref, q) => Stream.value(0),
              ),
              ruleStatusesProvider.overrideWith((ref, lang) async => []),
            ],
            child: Builder(
              builder: (context) => MaterialApp.router(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: AppTheme.light,
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 20 && find.text(entry).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(find.byType(V3HomeScreen), findsOneWidget);
      expect(find.text('v3.choose_activity'), findsNothing);
      await tester.ensureVisible(find.text(entry));
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();
      expect(find.byType(FreePracticeSheet), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(find.text('course.free_practice'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
