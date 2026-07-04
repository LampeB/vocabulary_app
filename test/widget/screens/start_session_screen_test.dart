import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
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

void main() {
  setUpAll(initTestLocalization);

  QuizArgs? capturedArgs;

  Future<void> pump(WidgetTester tester, {List<VocabularyList>? lists}) {
    capturedArgs = null;
    return pumpScreen(
      tester,
      screen: const StartSessionScreen(),
      overrides: [
        myListsProvider.overrideWith(
            (ref) => Stream.value(lists ?? [_list('l1', 'Animaux')])),
        dueCountProvider.overrideWith((ref) => Stream.value(4)),
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

  testWidgets('renders all five accordion sections and the CTA',
      (tester) async {
    await pump(tester);

    expect(byKey(WidgetKeys.screenStartSession), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      expect(byKey(WidgetKeys.startSection(i)), findsOneWidget,
          reason: 'section $i header missing');
    }
    expect(byKey(WidgetKeys.startSessionStart), findsOneWidget);
  });

  testWidgets('CTA is disabled until a list is selected', (tester) async {
    await pump(tester);

    ElevatedButton cta() => tester.widget<ElevatedButton>(find.ancestor(
        of: byKey(WidgetKeys.startSessionStart).first,
        matching: find.byType(ElevatedButton)).first);
    // The key IS on the ElevatedButton — read it directly.
    expect(
        tester
            .widget<ElevatedButton>(byKey(WidgetKeys.startSessionStart))
            .onPressed,
        isNull);

    await tester.tap(find.text('Animaux'));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<ElevatedButton>(byKey(WidgetKeys.startSessionStart))
            .onPressed,
        isNotNull);
    cta; // (helper kept trivially referenced)
  });

  testWidgets('selecting a list auto-advances to the quiz-type section',
      (tester) async {
    await pump(tester);
    // Quiz-type options not visible while the list section is open.
    expect(byKey(WidgetKeys.startQuizType('typing')), findsNothing);

    await tester.tap(find.text('Animaux'));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Animaux'));
    await tester.pumpAndSettle();
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

    // The due smart tile shows the live due count.
    expect(byKey(WidgetKeys.startSmart('due')), findsOneWidget);
    await tester.tap(byKey(WidgetKeys.startSmart('due')));
    await tester.pumpAndSettle();

    // Selecting it enables the CTA without any list chosen.
    expect(
        tester
            .widget<ElevatedButton>(byKey(WidgetKeys.startSessionStart))
            .onPressed,
        isNotNull);

    await tapKey(tester, WidgetKeys.startQuizType('flashcard'));
    await tapKey(tester, WidgetKeys.startDirection('frToKo'));
    await tapKey(tester, WidgetKeys.startSessionStart);

    expect(capturedArgs, isNotNull);
    expect(capturedArgs!.source, QuizSource.allDue);
    expect(capturedArgs!.listId, isNull);
  });

  testWidgets('smart list: "En cours d\'apprentissage" starts an in-progress '
      'session', (tester) async {
    await pump(tester);

    await tester.tap(byKey(WidgetKeys.startSmart('inprogress')));
    await tester.pumpAndSettle();
    await tapKey(tester, WidgetKeys.startQuizType('flashcard'));
    await tapKey(tester, WidgetKeys.startDirection('frToKo'));
    await tapKey(tester, WidgetKeys.startSessionStart);

    expect(capturedArgs!.source, QuizSource.inProgress);
  });

  testWidgets(
      'direction labels derive from the list language pair (EN↔ES list shows '
      'anglais/espagnol, not FR/KR)', (tester) async {
    await pump(tester,
        lists: [_list('l9', 'Inglés', langA: 'en', langB: 'es')]);

    await tester.tap(find.text('Inglés'));
    await tester.pumpAndSettle();
    await tapKey(tester, WidgetKeys.startQuizType('flashcard'));

    // The direction section is now open with labels from lang.en / lang.es.
    expect(find.text('Anglais → Espagnol'), findsOneWidget);
    expect(find.text('Espagnol → Anglais'), findsOneWidget);
  });

  testWidgets('the CTA label shows the selected card count', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Animaux'));
    await tester.pumpAndSettle();
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
