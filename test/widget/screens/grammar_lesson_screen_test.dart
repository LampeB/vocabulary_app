import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
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
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/core/theme/app_theme.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/settings/default_pair_provider.dart';
import 'package:vocab_kr/presentation/screens/grammar/grammar_lesson_screen.dart';
import 'package:vocab_kr/presentation/widgets/app_shell.dart';
import 'package:vocab_kr/presentation/widgets/scroll_affordance.dart';
import '../../helpers/pump_screen.dart';
import '../../helpers/rendered_text_contrast.dart';

class _KoreanToFrenchPair extends DefaultPairNotifier {
  @override
  (String, String) build() => ('ko', 'fr');
}

class _EnglishToKoreanPair extends DefaultPairNotifier {
  @override
  (String, String) build() => ('en', 'ko');
}

final _rule = GrammarRule(
  id: 'ko-topic',
  titles: const {'fr': 'La particule de thème'},
  descriptions: const {'fr': 'Choisis 은 ou 는.'},
  explanations: const {'fr': 'La particule de thème indique ce dont on parle.'},
  workedExamples: const [
    WorkedExample(
      target: '저는 학생이에요.',
      translations: {'fr': 'Je suis étudiant.'},
    ),
  ],
  prerequisiteLists: const [],
  appliesToCategories: const ['nom'],
  minKnownWords: const {'nom': 5},
  mechanics: const ParticleMechanics(
    variants: [
      ParticleVariant(key: 'default', afterConsonant: '은', afterVowel: '는'),
    ],
  ),
  testVectors: const [],
);

void main() {
  late GrammarRule actualRule;
  late GrammarRule actualFrenchNegation;
  late Map<String, dynamic> english;
  setUpAll(() async {
    await initTestLocalization();
    english =
        jsonDecode(await rootBundle.loadString('assets/translations/en.json'))
            as Map<String, dynamic>;
    final catalog =
        jsonDecode(
              await rootBundle.loadString('assets/seed/grammar/ko/rules.json'),
            )
            as Map<String, dynamic>;
    actualRule = (catalog['rules'] as List)
        .map((entry) => GrammarRule.fromJson(entry as Map<String, dynamic>))
        .firstWhere(
          (rule) => rule.id == 'particules-sujet-objet-i-ga-eul-reul',
        );
    final frenchCatalog =
        jsonDecode(
              await rootBundle.loadString('assets/seed/grammar/fr/rules.json'),
            )
            as Map<String, dynamic>;
    actualFrenchNegation = (frenchCatalog['rules'] as List)
        .map((entry) => GrammarRule.fromJson(entry as Map<String, dynamic>))
        .firstWhere((rule) => rule.id == 'fr-negation-ne-pas');
  });

  for (final paged in [false, true]) {
    testWidgets(
      'compact lesson in the real shell keeps reading and pagination, paged=$paged',
      (tester) async {
        final translations = Translations(english);
        Localization.load(
          const Locale('en'),
          translations: translations,
          fallbackTranslations: translations,
        );
        final previousLocale = Intl.defaultLocale;
        Intl.defaultLocale = 'en';
        addTearDown(() {
          Intl.defaultLocale = previousLocale;
        });
        addTearDown(initTestLocalization);
        final rule = !paged
            ? actualRule
            : GrammarRule(
                id: actualRule.id,
                titles: actualRule.titles,
                descriptions: actualRule.descriptions,
                explanations: actualRule.explanations,
                workedExamples: actualRule.workedExamples,
                prerequisiteLists: actualRule.prerequisiteLists,
                appliesToCategories: actualRule.appliesToCategories,
                minKnownWords: actualRule.minKnownWords,
                mechanics: actualRule.mechanics,
                testVectors: actualRule.testVectors,
                lessonPages: [
                  LessonPage(
                    type: 'explain',
                    texts: {'en': actualRule.explanation('en')},
                  ),
                  LessonPage(
                    type: 'explain',
                    texts: {'en': actualRule.workedExamples.first.target},
                  ),
                ],
              );
        var practiced = false;
        final router = GoRouter(
          initialLocation: '/grammar/lesson',
          routes: [
            ShellRoute(
              builder: (_, _, child) => AppShell(child: child),
              routes: [
                GoRoute(
                  path: '/grammar/lesson',
                  builder: (_, _) => GrammarLessonScreen(ruleId: rule.id),
                ),
              ],
            ),
            GoRoute(
              path: '/start-session-grammar',
              builder: (_, _) {
                practiced = true;
                return const Scaffold();
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        tester.view.physicalSize = const Size(568, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              grammarRulesProvider.overrideWith((ref, lang) async => [rule]),
              defaultPairProvider.overrideWith(_EnglishToKoreanPair.new),
              pushOnReconnectProvider.overrideWith((ref) {}),
              connectivityStreamProvider.overrideWith(
                (ref) => Stream.value([ConnectivityResult.wifi]),
              ),
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
        expect(find.text(rule.title('en')), findsOneWidget);
        final surface = find.byType(ScrollAffordance);
        final scroll = find.descendant(
          of: surface,
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scroll).position;
        expect(position.viewportDimension, greaterThan(80));
        expect(position.maxScrollExtent, greaterThan(0));
        final cue = find.descendant(
          of: surface,
          matching: find.text('lesson.scroll_hint'.tr()),
        );
        expect(
          tester
              .widget<AnimatedOpacity>(
                find
                    .ancestor(of: cue, matching: find.byType(AnimatedOpacity))
                    .first,
              )
              .opacity,
          1,
        );
        if (paged) {
          // A horizontal gesture still turns the page inside the compact scroller.
          await tester.drag(find.byType(PageView), const Offset(-450, 0));
          await tester.pumpAndSettle();
          final previous = find.text('lesson.previous'.tr());
          await tester.ensureVisible(previous);
          await tester.pumpAndSettle();
          await tester.tap(previous);
          await tester.pumpAndSettle();
          final next = find.text('lesson.next'.tr());
          await tester.ensureVisible(next);
          await tester.pumpAndSettle();
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
        final practice = find.byKey(
          const ValueKey(WidgetKeys.grammarLessonPractice),
        );
        await tester.ensureVisible(practice);
        await tester.pumpAndSettle();
        expect(practice.hitTestable(), findsOneWidget);
        await tester.tap(practice);
        await tester.pumpAndSettle();
        expect(practiced, isTrue);
        expect(tester.takeException(), isNull);
        await unmountScreen(tester);
      },
    );
  }

  for (final size in [const Size(568, 320), const Size(320, 568)]) {
    testWidgets(
      'actual KO to FR example popup scrolls its translation and close action at $size',
      (tester) async {
        await pumpScreen(
          tester,
          screen: AppShell(
            child: GrammarLessonScreen(ruleId: actualFrenchNegation.id),
          ),
          overrides: [
            defaultPairProvider.overrideWith(_KoreanToFrenchPair.new),
            grammarRulesProvider.overrideWith(
              (ref, lang) async => [actualFrenchNegation],
            ),
            pushOnReconnectProvider.overrideWith((ref) {}),
            connectivityStreamProvider.overrideWith(
              (ref) => Stream.value([ConnectivityResult.wifi]),
            ),
          ],
        );
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        final example = actualFrenchNegation.workedExamples.first;
        final opener = find.text(example.target);
        await tester.ensureVisible(opener);
        await tester.pumpAndSettle();
        final readerScroll = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(ScrollAffordance),
            matching: find.byType(Scrollable),
          ),
        );
        final savedOffset = readerScroll.position.pixels;
        final visibleTarget = tester
            .getRect(opener)
            .intersect(
              tester.getRect(
                find.descendant(
                  of: find.byType(ScrollAffordance),
                  matching: find.byType(Scrollable),
                ),
              ),
            );
        expect(visibleTarget.isEmpty, isFalse);
        await tester.tapAt(visibleTarget.center);
        await tester.pumpAndSettle();
        final dialog = find.byType(Dialog);
        final cue = find.descendant(
          of: dialog,
          matching: find.text('lesson.scroll_hint'.tr()),
        );
        expect(cue, findsOneWidget);
        final scroll = find.descendant(
          of: dialog,
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scroll).position;
        expect(position.maxScrollExtent, greaterThan(0));
        expect(
          tester
              .widget<AnimatedOpacity>(
                find
                    .ancestor(of: cue, matching: find.byType(AnimatedOpacity))
                    .first,
              )
              .opacity,
          1,
        );
        final translation = find.descendant(
          of: dialog,
          matching: find.text(example.translation('ko')),
        );
        await tester.ensureVisible(translation);
        await tester.pumpAndSettle();
        final viewport = tester.getRect(scroll);
        final translatedRect = tester.getRect(translation);
        expect(translatedRect.top, greaterThanOrEqualTo(viewport.top));
        expect(translatedRect.bottom, lessThanOrEqualTo(viewport.bottom));
        final close = find.descendant(
          of: dialog,
          matching: find.text('common.close'.tr()),
        );
        await tester.ensureVisible(close);
        await tester.pumpAndSettle();
        expect(close.hitTestable(), findsOneWidget);
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(readerScroll.position.pixels, savedOffset);
        expect(tester.takeException(), isNull);
        await unmountScreen(tester);
      },
    );
  }

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('example detail has readable contrast in ${theme.name}', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      useFallbackFontsForContrast();
      await pumpScreen(
        tester,
        screen: const GrammarLessonScreen(ruleId: 'ko-topic'),
        overrides: [
          grammarRulesProvider.overrideWith((ref, lang) async => [_rule]),
        ],
        themeMode: theme,
      );
      final contrast = await renderedTextContrast(
        tester,
        find.text('lesson.example_open'.tr()),
      );
      expect(contrast, inInclusiveRange(4.5, 21.0));
    });
  }

  testWidgets('opens contextual example details without leaving the lesson', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      screen: const GrammarLessonScreen(ruleId: 'ko-topic'),
      overrides: [
        grammarRulesProvider.overrideWith((ref, lang) async => [_rule]),
      ],
      settle: false,
    );

    expect(
      find.byKey(const ValueKey(WidgetKeys.screenGrammarLesson)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    expect(find.text(_rule.explanation('fr')), findsOneWidget);
    await tester.tap(find.text('저는 학생이에요.'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Je suis étudiant.'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('common.close'.tr()));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey(WidgetKeys.screenGrammarLesson)),
      findsOneWidget,
    );
  });

  testWidgets('continues from the final lesson page to practice', (
    tester,
  ) async {
    String? route;
    await pumpScreen(
      tester,
      screen: const GrammarLessonScreen(ruleId: 'ko-topic'),
      overrides: [
        grammarRulesProvider.overrideWith((ref, lang) async => [_rule]),
      ],
      routes: [
        GoRoute(
          path: '/start-session-grammar',
          builder: (_, state) {
            route = state.uri.toString();
            return const SizedBox();
          },
        ),
      ],
      settle: false,
    );

    await tester.tap(
      find.byKey(const ValueKey(WidgetKeys.grammarLessonPractice)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    final destination = Uri.parse(route!);
    expect(destination.path, '/start-session-grammar');
    expect(destination.queryParameters, {
      'rule': 'ko-topic',
      'langA': 'fr',
      'langB': 'ko',
    });
  });

  testWidgets('French lesson practice preserves its rule and Korean base', (
    tester,
  ) async {
    Uri? destination;
    String? curriculum;
    final french = GrammarRule(
      id: 'fr-articles-le-la',
      titles: const {'fr': 'Les articles'},
      descriptions: const {'fr': 'Choisir un article.'},
      explanations: const {
        'fr': 'Le pour un nom masculin.',
        'ko': '남성 명사 앞에는 le를 써요.',
      },
      workedExamples: const [
        WorkedExample(target: 'le café', translations: {'ko': '커피'}),
      ],
      prerequisiteLists: const [],
      appliesToCategories: const ['nom'],
      minKnownWords: const {'nom': 1},
      mechanics: const ArticleMechanics(forms: {'m': 'le', 'f': 'la'}),
      testVectors: const [],
    );
    await pumpScreen(
      tester,
      screen: const GrammarLessonScreen(ruleId: 'fr-articles-le-la'),
      overrides: [
        defaultPairProvider.overrideWith(_KoreanToFrenchPair.new),
        grammarRulesProvider.overrideWith((ref, lang) async {
          curriculum = lang;
          return [french];
        }),
      ],
      routes: [
        GoRoute(
          path: '/start-session-grammar',
          builder: (_, state) {
            destination = state.uri;
            return const SizedBox();
          },
        ),
      ],
      settle: false,
    );
    expect(curriculum, 'fr');
    // Teaching follows the Korean base while navigation remains in French.
    expect(find.text('Leçon'), findsOneWidget);
    expect(find.text('Les articles'), findsOneWidget);
    expect(find.text('남성 명사 앞에는 le를 써요.'), findsOneWidget);
    expect(find.text('Le pour un nom masculin.'), findsNothing);
    await tester.tap(find.text('le café'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('커피')),
      findsOneWidget,
    );
    await tester.tap(find.text('common.close'.tr()));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(
      find.byKey(const ValueKey(WidgetKeys.grammarLessonPractice)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(destination!.path, '/start-session-grammar');
    expect(destination!.queryParameters, {
      'rule': 'fr-articles-le-la',
      'langA': 'ko',
      'langB': 'fr',
    });
  });
}
