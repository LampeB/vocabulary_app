import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/screens/grammar/grammar_lesson_screen.dart';
import 'package:vocab_kr/presentation/screens/grammar/grammar_screen.dart';
import 'package:vocab_kr/presentation/screens/home/daily_path_screen.dart';
import 'package:vocab_kr/presentation/screens/home/v3_home_screen.dart';
import 'package:vocab_kr/presentation/screens/quiz/start_session_screen.dart';
import 'package:vocab_kr/presentation/design/v3/v3_card_stack.dart';
import '../../helpers/pump_screen.dart';

/// Start-session screen: a language-first accordion. Pick the language, then a
/// list (split into currently-studying / not-yet-studied), then mode /
/// direction / count. The CTA fires /quiz with exactly the QuizArgs assembled.

final _now = DateTime(2026, 7, 3);

const _frenchPlural = GrammarRule(
  id: 'fr-plural-s',
  titles: {'fr': 'Le pluriel en -s', 'ko': '-s 복수형'},
  descriptions: {},
  explanations: {'fr': 'On ajoute un s au nom.', 'ko': '명사 뒤에 s를 붙여요.'},
  workedExamples: [
    WorkedExample(
      target: 'les pommes',
      translations: {'fr': 'des pommes', 'ko': '사과 여러 개'},
    ),
  ],
  prerequisiteLists: [],
  appliesToCategories: ['nom'],
  minKnownWords: {'nom': 1},
  mechanics: PluralMechanics(irregulars: {}),
  testVectors: [],
);

VocabularyList _list(
  String id,
  String name, {
  int wordCount = 5,
  String langA = 'fr',
  String langB = 'ko',
}) => VocabularyList(
  id: id,
  ownerId: 'u',
  name: name,
  wordCount: wordCount,
  langA: langA,
  langB: langB,
  createdAt: _now,
  updatedAt: _now,
);

GrammarRule _rule(String id, String title) => GrammarRule(
  id: id,
  titles: {'fr': title},
  descriptions: const {'fr': ''},
  explanations: const {'fr': 'Une explication.'},
  workedExamples: const [
    WorkedExample(target: '저는 학생이에요', translations: {'fr': 'Je suis étudiant'}),
  ],
  prerequisiteLists: const ['Salutations & politesse'],
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
  setUpAll(initTestLocalization);

  QuizArgs? capturedArgs;

  Future<void> pump(
    WidgetTester tester, {
    List<VocabularyList>? lists,
    Set<String> studied = const {},
    bool grammar = false,
    String? initialRuleId,
    String? langA,
    String? langB,
    GrammarRule? rule,
  }) {
    capturedArgs = null;
    return pumpScreen(
      tester,
      screen: StartSessionScreen(
        grammar: grammar,
        initialRuleId: initialRuleId,
        initialLangA: langA,
        initialLangB: langB,
      ),
      overrides: [
        myListsProvider.overrideWith(
          (ref) => Stream.value(lists ?? [_list('l1', 'Animaux')]),
        ),
        dueCountProvider.overrideWith((ref) => Stream.value(4)),
        dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(4)),
        studiedListIdsProvider.overrideWith((ref) => Stream.value(studied)),
        ruleStatusesProvider.overrideWith(
          (ref, lang) async => [
            RuleStatus(
              rule:
                  rule ??
                  _rule(
                    initialRuleId ?? 'regle-debloquee',
                    'La particule de thème',
                  ),
              availability: RuleAvailability.unlocked,
              missingLists: const [],
              enoughWords: true,
              correct: 3,
            ),
            RuleStatus(
              rule: _rule('regle-verrouillee', 'Le présent poli'),
              availability: RuleAvailability.locked,
              missingLists: const ['La nourriture'],
              enoughWords: true,
              correct: 0,
            ),
          ],
        ),
      ],
      routes: [
        GoRoute(
          path: '/quiz',
          builder: (_, state) {
            capturedArgs = state.extra as QuizArgs?;
            return const Scaffold(body: SizedBox());
          },
        ),
      ],
    );
  }

  Finder byKey(String key) => find.byKey(ValueKey(key));

  for (final entry in {
    'fr': [
      'CONFIGURER',
      'LES CARTES SONT DÉPILÉES',
      'DERNIÈRE CARTE',
      '3 CARTES À DÉPILER',
    ],
    'en': ['SET UP', 'ALL CARDS DONE', 'LAST CARD', '3 CARDS LEFT'],
    'ko': ['학습 설정', '모든 카드를 마쳤어요', '마지막 카드', '남은 카드 3장'],
  }.entries) {
    testWidgets('setup and remaining counters use ${entry.key}', (
      tester,
    ) async {
      final raw = (await tester.runAsync(
        () => rootBundle.loadString('assets/translations/${entry.key}.json'),
      ))!;
      final translations = Translations(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      Localization.load(
        Locale(entry.key),
        translations: translations,
        fallbackTranslations: translations,
      );
      addTearDown(initTestLocalization);
      await pump(tester);
      expect(find.text(entry.value[0]), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                V3StackCounter(remaining: 0),
                V3StackCounter(remaining: 1),
                V3StackCounter(remaining: 3),
              ],
            ),
          ),
        ),
      );
      for (final label in entry.value.skip(1)) {
        expect(find.text(label), findsOneWidget);
      }
      await unmountScreen(tester);
    });
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(byKey(key));
    await tester.tap(byKey(key), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> activateByKeyboard(WidgetTester tester, String key) async {
    final element = tester.element(byKey(key));
    bool containsFocus() {
      final focused = FocusManager.instance.primaryFocus?.context as Element?;
      if (focused == element) return true;
      var found = false;
      focused?.visitAncestorElements((ancestor) {
        found = ancestor == element;
        return !found;
      });
      return found;
    }

    for (var tabs = 0; tabs < 20 && !containsFocus(); tabs++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(containsFocus(), isTrue, reason: '$key must be reachable by Tab');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
  }

  // Language step is first: open it, pick the pair, then the list step opens.
  Future<void> pickLanguage(WidgetTester tester, {String langB = 'ko'}) async {
    await tapKey(tester, WidgetKeys.startSection(0));
    await tester.tap(byKey(WidgetKeys.startLanguage(langB)));
    await tester.pumpAndSettle();
  }

  Future<void> pickList(
    WidgetTester tester,
    String name, {
    String langB = 'ko',
  }) async {
    await pickLanguage(tester, langB: langB);
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> pumpTrail(WidgetTester tester) {
    final rule = _rule('ko-topic', 'La particule de thème');
    return pumpScreen(
      tester,
      screen: const TickerMode(enabled: false, child: V3HomeScreen()),
      overrides: [
        currentUserProvider.overrideWithValue(null),
        myListsProvider.overrideWith(
          (ref) => Stream.value([_list('l1', 'Animaux')]),
        ),
        dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(4)),
        studiedListIdsProvider.overrideWith((ref) => Stream.value(const {})),
        grammarRulesProvider.overrideWith((ref, lang) async => [rule]),
        ruleStatusesProvider.overrideWith(
          (ref, lang) async => [
            RuleStatus(
              rule: rule,
              availability: RuleAvailability.unlocked,
              missingLists: const [],
              enoughWords: true,
              correct: 0,
            ),
          ],
        ),
      ],
      routes: [
        GoRoute(
          path: '/daily-path',
          builder: (_, _) => const DailyPathScreen(),
        ),
        GoRoute(path: '/grammar', builder: (_, _) => const GrammarScreen()),
        GoRoute(
          path: '/grammar/:ruleId',
          builder: (_, state) =>
              GrammarLessonScreen(ruleId: state.pathParameters['ruleId']!),
        ),
        GoRoute(
          path: '/start-session',
          builder: (_, _) => const StartSessionScreen(),
        ),
        GoRoute(
          path: '/start-session-grammar',
          builder: (_, state) => StartSessionScreen(
            grammar: true,
            initialRuleId: state.uri.queryParameters['rule'],
            initialLangA: state.uri.queryParameters['langA'],
            initialLangB: state.uri.queryParameters['langB'],
          ),
        ),
        GoRoute(
          path: '/quiz',
          builder: (context, _) => Scaffold(
            body: BackButton(
              key: const ValueKey('quiz-back'),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> appBarBack(WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    final back = find.byTooltip('common.back'.tr());
    expect(back, findsOneWidget);
    expect(
      tester.getSemantics(back).getSemanticsData().tooltip,
      'common.back'.tr(),
    );
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    semantics.dispose();
  }

  testWidgets('quiz preserves setup and the plateau below it', (tester) async {
    await pumpTrail(tester);
    final activity = find.text('v3.choose_activity'.tr());
    await tester.ensureVisible(activity);
    await tester.tap(activity);
    await tester.pumpAndSettle();
    await tester.tap(find.text('v3.choose_quiz'.tr()));
    await tester.pumpAndSettle();
    expect(byKey(WidgetKeys.screenStartSession), findsOneWidget);

    await pickLanguage(tester);
    await tapKey(tester, WidgetKeys.startSmart('due'));
    await tapKey(tester, WidgetKeys.startQuizType('typing'));
    await tapKey(tester, WidgetKeys.startDirection('frToKo'));
    await tapKey(tester, WidgetKeys.startCount(20));
    await tapKey(tester, WidgetKeys.startSessionStart);
    await tapKey(tester, 'quiz-back');
    expect(byKey(WidgetKeys.screenStartSession), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(byKey(WidgetKeys.startSessionStart))
          .onPressed,
      isNotNull,
    );
    await appBarBack(tester);
    expect(byKey(WidgetKeys.screenHome), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'lesson quiz returns through setup and reader to the daily path',
    (tester) async {
      await pumpTrail(tester);
      await tapKey(tester, WidgetKeys.homeDailyPath);
      await tapKey(tester, WidgetKeys.dailyPathLessons);
      await tapKey(tester, WidgetKeys.grammarRuleOpenLesson('ko-topic'));
      await tapKey(tester, WidgetKeys.grammarLessonPractice);
      await tapKey(tester, WidgetKeys.startQuizType('typing'));
      await tapKey(tester, WidgetKeys.startCount(10));
      await tapKey(tester, WidgetKeys.startSessionStart);

      await tapKey(tester, 'quiz-back');
      expect(byKey(WidgetKeys.screenStartSession), findsOneWidget);
      await appBarBack(tester);
      expect(byKey(WidgetKeys.screenGrammarLesson), findsOneWidget);
      await appBarBack(tester);
      expect(byKey(WidgetKeys.screenGrammar), findsOneWidget);
      await appBarBack(tester);
      expect(byKey(WidgetKeys.screenDailyPath), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'vocab flow renders its five sections — and NO grammar anywhere',
    (tester) async {
      await pump(tester);

      expect(byKey(WidgetKeys.screenStartSession), findsOneWidget);
      // Language, List, Type, Direction, Count.
      for (var i = 0; i < 5; i++) {
        expect(
          byKey(WidgetKeys.startSection(i)),
          findsOneWidget,
          reason: 'section $i header missing',
        );
      }
      expect(byKey(WidgetKeys.startSessionStart), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
      expect(find.textContaining('rammaire'), findsNothing);
      expect(byKey(WidgetKeys.startRule('regle-debloquee')), findsNothing);
    },
  );

  testWidgets('keyboard selects mode and count and starts the quiz', (
    tester,
  ) async {
    await pump(tester);

    bool? selected(String key) {
      final button = find.descendant(
        of: byKey(key),
        matching: find.byType(OutlinedButton),
      );
      final data = tester.getSemantics(button).getSemanticsData();
      final flags = data.flagsCollection;
      expect(flags.isButton, isTrue, reason: '$key must expose a button');
      return flags.isSelected.toBoolOrNull();
    }

    final semantics = tester.ensureSemantics();
    try {
      final typing = WidgetKeys.startQuizType('typing');
      final count = WidgetKeys.startCount(20);
      await activateByKeyboard(tester, WidgetKeys.startSection(0));
      await activateByKeyboard(tester, WidgetKeys.startLanguage('ko'));
      await activateByKeyboard(tester, WidgetKeys.startSmart('due'));
      expect(selected(typing), isFalse);
      await activateByKeyboard(tester, typing);
      await activateByKeyboard(tester, WidgetKeys.startDirection('frToKo'));
      expect(selected(count), isFalse);
      await activateByKeyboard(tester, count);

      await activateByKeyboard(tester, WidgetKeys.startSection(2));
      expect(selected(typing), isTrue);
      await activateByKeyboard(tester, WidgetKeys.startSection(4));
      expect(selected(count), isTrue);
      await activateByKeyboard(tester, count);
      await activateByKeyboard(tester, WidgetKeys.startSessionStart);
    } finally {
      semantics.dispose();
    }

    expect(capturedArgs?.source, QuizSource.allDue);
    expect(capturedArgs?.mode, QuizMode.typing);
    expect(capturedArgs?.cardLimit, 20);
  });

  testWidgets(
    'no defaults: every section starts collapsed and the CTA stays disabled '
    'until language + list + mode + direction + count are all chosen',
    (tester) async {
      await pump(tester);

      bool ctaEnabled() =>
          tester
              .widget<ElevatedButton>(byKey(WidgetKeys.startSessionStart))
              .onPressed !=
          null;

      expect(find.text('Animaux'), findsNothing);
      expect(byKey(WidgetKeys.startQuizType('typing')), findsNothing);
      expect(byKey(WidgetKeys.startCount(20)), findsNothing);
      expect(ctaEnabled(), isFalse);

      await pickLanguage(tester);
      expect(ctaEnabled(), isFalse); // language alone isn't enough
      await tester.tap(find.text('Animaux'));
      await tester.pumpAndSettle();
      expect(ctaEnabled(), isFalse);
      await tapKey(tester, WidgetKeys.startQuizType('typing'));
      expect(ctaEnabled(), isFalse);
      await tapKey(tester, WidgetKeys.startDirection('frToKo'));
      expect(ctaEnabled(), isFalse);
      await tapKey(tester, WidgetKeys.startCount(20));
      expect(ctaEnabled(), isTrue);
    },
  );

  testWidgets('picking a language reveals its lists; selecting one advances '
      'to the quiz-type section', (tester) async {
    await pump(tester);
    expect(find.text('Animaux'), findsNothing);

    await pickLanguage(tester);
    expect(find.text('Animaux'), findsOneWidget); // list step now open

    await tester.tap(find.text('Animaux'));
    await tester.pumpAndSettle();
    expect(byKey(WidgetKeys.startQuizType('typing')), findsOneWidget);
  });

  testWidgets('lists split into "currently studying" and "not yet studied"', (
    tester,
  ) async {
    await pump(
      tester,
      lists: [_list('l1', 'Voyage'), _list('l2', 'Cuisine')],
      studied: {'l1'}, // Voyage has been studied, Cuisine has not
    );

    await pickLanguage(tester);

    expect(find.text('EN COURS D\'ÉTUDE'), findsOneWidget);
    expect(find.text('PAS ENCORE ÉTUDIÉES'), findsOneWidget);
    expect(find.text('Voyage'), findsOneWidget);
    expect(find.text('Cuisine'), findsOneWidget);
  });

  testWidgets('empty lists: no language to pick and the CTA stays disabled', (
    tester,
  ) async {
    await pump(tester, lists: []);

    await tapKey(tester, WidgetKeys.startSection(0));
    expect(
      tester
          .widget<ElevatedButton>(byKey(WidgetKeys.startSessionStart))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'full journey: language → list → mode → direction → count → start fires '
    '/quiz with the assembled QuizArgs',
    (tester) async {
      await pump(tester);

      await pickList(tester, 'Animaux');
      await tapKey(tester, WidgetKeys.startQuizType('typing'));
      await tapKey(tester, WidgetKeys.startDirection('both'));
      await tapKey(tester, WidgetKeys.startCount(50));
      await tapKey(tester, WidgetKeys.startSessionStart);

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.listId, 'l1');
      expect(capturedArgs!.mode, QuizMode.typing);
      expect(capturedArgs!.direction, QuizDirectionChoice.both);
      expect(capturedArgs!.cardLimit, 50);
    },
  );

  testWidgets(
    'smart list: picking "À réviser maintenant" (after a language) starts an '
    'all-due session scoped to that pair (no listId)',
    (tester) async {
      await pump(tester);

      await pickLanguage(tester);
      expect(byKey(WidgetKeys.startSmart('due')), findsOneWidget);
      await tester.tap(byKey(WidgetKeys.startSmart('due')));
      await tester.pumpAndSettle();

      await tapKey(tester, WidgetKeys.startQuizType('flashcard'));
      await tapKey(tester, WidgetKeys.startDirection('frToKo'));
      await tapKey(tester, WidgetKeys.startCount(20));
      await tapKey(tester, WidgetKeys.startSessionStart);

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.source, QuizSource.allDue);
      expect(capturedArgs!.listId, isNull);
      // Scoped to the chosen language, not reset to fr/ko defaults here.
      expect(capturedArgs!.langA, 'fr');
      expect(capturedArgs!.langB, 'ko');
    },
  );

  testWidgets('smart list: "En cours" starts an in-progress session', (
    tester,
  ) async {
    await pump(tester);

    await pickLanguage(tester);
    await tester.tap(byKey(WidgetKeys.startSmart('inprogress')));
    await tester.pumpAndSettle();
    await tapKey(tester, WidgetKeys.startQuizType('flashcard'));
    await tapKey(tester, WidgetKeys.startDirection('frToKo'));
    await tapKey(tester, WidgetKeys.startCount(20));
    await tapKey(tester, WidgetKeys.startSessionStart);

    expect(capturedArgs!.source, QuizSource.inProgress);
  });

  testWidgets(
    'a non-FR/KO pair: direction labels derive from the list language pair '
    '(FR↔ES shows français/espagnol, not FR/KR)',
    (tester) async {
      await pump(
        tester,
        lists: [_list('l9', 'Voyage', langA: 'fr', langB: 'es')],
      );

      await pickList(tester, 'Voyage', langB: 'es');
      await tapKey(tester, WidgetKeys.startQuizType('flashcard'));

      expect(find.text('Français → Espagnol'), findsOneWidget);
      expect(find.text('Espagnol → Français'), findsOneWidget);
    },
  );

  testWidgets(
    'grammar flow: unlocked rule opens the lesson sheet, starting fires '
    '/quiz with a grammar source; locked rules are disabled',
    (tester) async {
      await pump(tester, grammar: true);

      // No language step for grammar — the rule section is first.
      await tapKey(tester, WidgetKeys.startSection(0));

      expect(find.textContaining('La nourriture'), findsOneWidget);

      await tester.tap(byKey(WidgetKeys.startRule('regle-debloquee')));
      await tester.pumpAndSettle();
      expect(find.text('Une explication.'), findsOneWidget);
      expect(find.text('저는 학생이에요'), findsOneWidget);

      await tester.tap(byKey(WidgetKeys.grammarLessonStart));
      await tester.pumpAndSettle();

      await tapKey(tester, WidgetKeys.startQuizType('typing'));
      expect(byKey(WidgetKeys.startDirection('frToKo')), findsNothing);
      await tapKey(tester, WidgetKeys.startCount(10));
      await tapKey(tester, WidgetKeys.startSessionStart);

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!.source, QuizSource.grammar);
      expect(capturedArgs!.ruleId, 'regle-debloquee');
      expect(capturedArgs!.mode, QuizMode.typing);
    },
  );

  testWidgets(
    'French lesson keeps its exact rule and Korean base through setup',
    (tester) async {
      await pump(
        tester,
        grammar: true,
        initialRuleId: 'fr-articles-le-la',
        langA: 'ko',
        langB: 'fr',
      );
      await tapKey(tester, WidgetKeys.startQuizType('typing'));
      await tapKey(tester, WidgetKeys.startCount(10));
      await tapKey(tester, WidgetKeys.startSessionStart);
      expect(capturedArgs!.source, QuizSource.grammar);
      expect(capturedArgs!.ruleId, 'fr-articles-le-la');
      expect(capturedArgs!.langA, 'ko');
      expect(capturedArgs!.langB, 'fr');
    },
  );

  testWidgets('French plural preview teaches in Korean and starts in writing', (
    tester,
  ) async {
    await pump(
      tester,
      grammar: true,
      langA: 'ko',
      langB: 'fr',
      rule: _frenchPlural,
    );
    await tapKey(tester, WidgetKeys.startSection(0));
    await tapKey(tester, WidgetKeys.startRule('fr-plural-s'));

    expect(find.text('명사 뒤에 s를 붙여요.'), findsOneWidget);
    expect(find.text('사과 여러 개'), findsOneWidget);
    expect(find.text('les pommes'), findsOneWidget);
    expect(find.text('On ajoute un s au nom.'), findsNothing);
    expect(find.text('des pommes'), findsNothing);
    expect(find.text('Exemples'), findsOneWidget);
    expect(find.text("C'est parti !"), findsOneWidget);

    await tapKey(tester, WidgetKeys.grammarLessonStart);
    for (final mode in ['voice', 'handsFree']) {
      final choice = byKey(WidgetKeys.startQuizType(mode));
      final button = find.descendant(
        of: choice,
        matching: find.byType(OutlinedButton),
      );
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      await tapKey(tester, WidgetKeys.startQuizType(mode));
      expect(byKey(WidgetKeys.startCount(10)), findsNothing);
    }
    await tapKey(tester, WidgetKeys.startQuizType('typing'));
    await tapKey(tester, WidgetKeys.startCount(10));
    await tapKey(tester, WidgetKeys.startSessionStart);
    expect(capturedArgs?.ruleId, 'fr-plural-s');
    expect(capturedArgs?.mode, QuizMode.typing);
    expect(capturedArgs?.langA, 'ko');
    expect(capturedArgs?.langB, 'fr');
  });

  testWidgets(
    'real French lesson preview scrolls at 320x568 with double text',
    (tester) async {
      final raw = (await tester.runAsync(
        () => rootBundle.loadString('assets/seed/grammar/fr/rules.json'),
      ))!;
      final rules = (jsonDecode(raw) as Map<String, dynamic>)['rules'] as List;
      final rule = rules
          .map((json) => GrammarRule.fromJson(json as Map<String, dynamic>))
          .firstWhere((r) => r.id == 'fr-articles-le-la');
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, grammar: true, langA: 'ko', langB: 'fr', rule: rule);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      final title = find.text('start_session.title_grammar'.tr());
      expect(
        find.ancestor(of: title, matching: find.byType(Scrollable)),
        findsOneWidget,
      );
      final titleRect = tester.getRect(title);
      final viewport = tester.getRect(find.byType(Scrollable).first);
      expect(titleRect.top, greaterThanOrEqualTo(viewport.top));
      expect(titleRect.bottom, lessThanOrEqualTo(viewport.bottom));
      await tapKey(tester, WidgetKeys.startSection(0));
      await tapKey(tester, WidgetKeys.startRule(rule.id));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(byKey(WidgetKeys.grammarLessonStart));
      await tester.pumpAndSettle();
      await tester.tap(byKey(WidgetKeys.grammarLessonStart));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(byKey(WidgetKeys.startQuizType('typing')), findsOneWidget);
      await unmountScreen(tester);
    },
  );

  testWidgets('the CTA label shows the selected card count', (tester) async {
    await pump(tester);
    await pickList(tester, 'Animaux');
    await tapKey(tester, WidgetKeys.startQuizType('flashcard'));
    await tapKey(tester, WidgetKeys.startDirection('frToKo'));
    await tapKey(tester, WidgetKeys.startCount(100));

    final label = tester
        .widget<Text>(
          find.descendant(
            of: byKey(WidgetKeys.startSessionStart),
            matching: find.byType(Text),
          ),
        )
        .data;
    expect(label, contains('100'));
  });
}
