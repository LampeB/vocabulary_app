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

/// Start-session screen: the accordion renders every section, list selection
/// enables the CTA and auto-advances, and the CTA fires /quiz with exactly the
/// QuizArgs the user assembled.

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
      {List<VocabularyList>? lists, bool grammar = false}) {
    capturedArgs = null;
    return pumpScreen(
      tester,
      screen: StartSessionScreen(grammar: grammar),
      overrides: [
        myListsProvider.overrideWith(
            (ref) => Stream.value(lists ?? [_list('l1', 'Animaux')])),
        dueCountProvider.overrideWith((ref) => Stream.value(4)),
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

  // Everything starts collapsed — open the first section, then pick a list.
  Future<void> pickList(WidgetTester tester, String name) async {
    await tapKey(tester, WidgetKeys.startSection(0));
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('vocab flow renders its four sections — and NO grammar anywhere',
      (tester) async {
    await pump(tester);

    expect(byKey(WidgetKeys.screenStartSession), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      expect(byKey(WidgetKeys.startSection(i)), findsOneWidget,
          reason: 'section $i header missing');
    }
    expect(byKey(WidgetKeys.startSessionStart), findsOneWidget);
    // Vocabulary setup never mentions grammar (product decision 2026-07-05).
    expect(find.textContaining('rammaire'), findsNothing);
    expect(byKey(WidgetKeys.startRule('regle-debloquee')), findsNothing);
  });

  testWidgets(
      'no defaults: every section starts collapsed and empty, and the CTA '
      'stays disabled until EVERY field is chosen', (tester) async {
    await pump(tester);

    bool ctaEnabled() =>
        tester
            .widget<ElevatedButton>(byKey(WidgetKeys.startSessionStart))
            .onPressed !=
        null;

    // All collapsed: no option from any section is in the tree.
    expect(find.text('Animaux'), findsNothing);
    expect(byKey(WidgetKeys.startQuizType('typing')), findsNothing);
    expect(byKey(WidgetKeys.startCount(20)), findsNothing);
    expect(ctaEnabled(), isFalse);

    await pickList(tester, 'Animaux');
    expect(ctaEnabled(), isFalse); // mode, direction, count still unset
    await tapKey(tester, WidgetKeys.startQuizType('typing'));
    expect(ctaEnabled(), isFalse);
    await tapKey(tester, WidgetKeys.startDirection('frToKo'));
    expect(ctaEnabled(), isFalse);
    await tapKey(tester, WidgetKeys.startCount(20));
    expect(ctaEnabled(), isTrue);
  });

  testWidgets('selecting a list auto-advances to the quiz-type section',
      (tester) async {
    await pump(tester);
    // Quiz-type options not visible before the list is chosen.
    expect(byKey(WidgetKeys.startQuizType('typing')), findsNothing);

    await pickList(tester, 'Animaux');

    expect(byKey(WidgetKeys.startQuizType('typing')), findsOneWidget);
  });

  testWidgets('empty lists show the empty message and CTA stays disabled',
      (tester) async {
    await pump(tester, lists: []);

    expect(
        tester
            .widget<ElevatedButton>(byKey(WidgetKeys.startSessionStart))
            .onPressed,
        isNull);
  });

  testWidgets(
      'full journey: list → mode → direction → count → start fires /quiz '
      'with the assembled QuizArgs', (tester) async {
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
      'smart list: picking "À réviser maintenant" enables the CTA and starts '
      'an all-due session (no listId)', (tester) async {
    await pump(tester);

    // The due smart tile shows the live due count (open the section first).
    await tapKey(tester, WidgetKeys.startSection(0));
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
  });

  testWidgets('smart list: "En cours d\'apprentissage" starts an in-progress '
      'session', (tester) async {
    await pump(tester);

    await tapKey(tester, WidgetKeys.startSection(0));
    await tester.tap(byKey(WidgetKeys.startSmart('inprogress')));
    await tester.pumpAndSettle();
    await tapKey(tester, WidgetKeys.startQuizType('flashcard'));
    await tapKey(tester, WidgetKeys.startDirection('frToKo'));
    await tapKey(tester, WidgetKeys.startCount(20));
    await tapKey(tester, WidgetKeys.startSessionStart);

    expect(capturedArgs!.source, QuizSource.inProgress);
  });

  testWidgets(
      'direction labels derive from the list language pair (EN↔ES list shows '
      'anglais/espagnol, not FR/KR)', (tester) async {
    await pump(tester,
        lists: [_list('l9', 'Inglés', langA: 'en', langB: 'es')]);

    await pickList(tester, 'Inglés');
    await tapKey(tester, WidgetKeys.startQuizType('flashcard'));

    // The direction section is now open with labels from lang.en / lang.es.
    expect(find.text('Anglais → Espagnol'), findsOneWidget);
    expect(find.text('Espagnol → Anglais'), findsOneWidget);
  });

  testWidgets(
      'grammar flow: unlocked rule opens the lesson sheet, starting fires '
      '/quiz with a grammar source; locked rules are disabled', (tester) async {
    await pump(tester, grammar: true);

    // Rule section starts collapsed too — open it.
    await tapKey(tester, WidgetKeys.startSection(0));

    // Locked rule: disabled, shows what to master first.
    expect(find.textContaining('La nourriture'), findsOneWidget);

    // Unlocked rule → lesson sheet with the explanation.
    await tester.tap(byKey(WidgetKeys.startRule('regle-debloquee')));
    await tester.pumpAndSettle();
    expect(find.text('Une explication.'), findsOneWidget);
    expect(find.text('저는 학생이에요'), findsOneWidget);

    await tester.tap(byKey(WidgetKeys.grammarLessonStart));
    await tester.pumpAndSettle();

    // Direction section is skipped for grammar; mode then count then start.
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
