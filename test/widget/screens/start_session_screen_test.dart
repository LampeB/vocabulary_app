import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/domain/entities/grammar_rule.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/screens/quiz/start_session_screen.dart';
import '../../helpers/pump_screen.dart';

/// Start-session screen: a language-first accordion. Pick the language, then a
/// list (split into currently-studying / not-yet-studied), then mode /
/// direction / count. The CTA fires /quiz with exactly the QuizArgs assembled.

final _now = DateTime(2026, 7, 3);

VocabularyList _list(String id, String name,
        {int wordCount = 5, String langA = 'fr', String langB = 'ko'}) =>
    VocabularyList(
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
      titleFr: title,
      descriptionFr: '',
      explanationFr: 'Une explication.',
      workedExamples: const [WorkedExample(ko: '저는 학생이에요', fr: 'Je suis étudiant')],
      prerequisiteLists: const ['Salutations & politesse'],
      appliesToCategories: const ['nom'],
      minKnownWords: const {'nom': 5},
      mechanics: const ParticleMechanics(variants: [
        ParticleVariant(key: 'default', afterConsonant: '은', afterVowel: '는'),
      ]),
      testVectors: const [],
    );

void main() {
  setUpAll(initTestLocalization);

  QuizArgs? capturedArgs;

  Future<void> pump(WidgetTester tester,
      {List<VocabularyList>? lists,
      Set<String> studied = const {},
      bool grammar = false}) {
    capturedArgs = null;
    return pumpScreen(
      tester,
      screen: StartSessionScreen(grammar: grammar),
      overrides: [
        myListsProvider.overrideWith(
            (ref) => Stream.value(lists ?? [_list('l1', 'Animaux')])),
        dueCountProvider.overrideWith((ref) => Stream.value(4)),
        dueCountForPairProvider.overrideWith((ref, pair) => Stream.value(4)),
        studiedListIdsProvider.overrideWith((ref) => Stream.value(studied)),
        ruleStatusesProvider.overrideWith((ref) async => [
              RuleStatus(
                rule: _rule('regle-debloquee', 'La particule de thème'),
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
            ]),
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

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(byKey(key));
    await tester.tap(byKey(key), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  // Language step is first: open it, pick the pair, then the list step opens.
  Future<void> pickLanguage(WidgetTester tester, {String langB = 'ko'}) async {
    await tapKey(tester, WidgetKeys.startSection(0));
    await tester.tap(byKey(WidgetKeys.startLanguage(langB)));
    await tester.pumpAndSettle();
  }

  Future<void> pickList(WidgetTester tester, String name,
      {String langB = 'ko'}) async {
    await pickLanguage(tester, langB: langB);
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('vocab flow renders its five sections — and NO grammar anywhere',
      (tester) async {
    await pump(tester);

    expect(byKey(WidgetKeys.screenStartSession), findsOneWidget);
    // Language, List, Type, Direction, Count.
    for (var i = 0; i < 5; i++) {
      expect(byKey(WidgetKeys.startSection(i)), findsOneWidget,
          reason: 'section $i header missing');
    }
    expect(byKey(WidgetKeys.startSessionStart), findsOneWidget);
    expect(find.textContaining('rammaire'), findsNothing);
    expect(byKey(WidgetKeys.startRule('regle-debloquee')), findsNothing);
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
  });

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

  testWidgets('lists split into "currently studying" and "not yet studied"',
      (tester) async {
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

  testWidgets('empty lists: no language to pick and the CTA stays disabled',
      (tester) async {
    await pump(tester, lists: []);

    await tapKey(tester, WidgetKeys.startSection(0));
    expect(
        tester
            .widget<ElevatedButton>(byKey(WidgetKeys.startSessionStart))
            .onPressed,
        isNull);
  });

  testWidgets(
      'full journey: language → list → mode → direction → count → start fires '
      '/quiz with the assembled QuizArgs', (tester) async {
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
  });

  testWidgets(
      'smart list: picking "À réviser maintenant" (after a language) starts an '
      'all-due session scoped to that pair (no listId)', (tester) async {
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
  });

  testWidgets('smart list: "En cours" starts an in-progress session',
      (tester) async {
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
      '(FR↔ES shows français/espagnol, not FR/KR)', (tester) async {
    await pump(tester,
        lists: [_list('l9', 'Voyage', langA: 'fr', langB: 'es')]);

    await pickList(tester, 'Voyage', langB: 'es');
    await tapKey(tester, WidgetKeys.startQuizType('flashcard'));

    expect(find.text('Français → Espagnol'), findsOneWidget);
    expect(find.text('Espagnol → Français'), findsOneWidget);
  });

  testWidgets(
      'grammar flow: unlocked rule opens the lesson sheet, starting fires '
      '/quiz with a grammar source; locked rules are disabled', (tester) async {
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
  });

  testWidgets('the CTA label shows the selected card count', (tester) async {
    await pump(tester);
    await pickList(tester, 'Animaux');
    await tapKey(tester, WidgetKeys.startQuizType('flashcard'));
    await tapKey(tester, WidgetKeys.startDirection('frToKo'));
    await tapKey(tester, WidgetKeys.startCount(100));

    final label = tester
        .widget<Text>(find.descendant(
            of: byKey(WidgetKeys.startSessionStart),
            matching: find.byType(Text)))
        .data;
    expect(label, contains('100'));
  });
}
