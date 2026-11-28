import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/theme/app_colors.dart';
import 'package:vocab_kr/presentation/widgets/study/study_feedback_flood.dart';
import '../helpers/pump_screen.dart';

void main() {
  setUpAll(initTestLocalization);
  Future<void> pump(WidgetTester tester, Widget w) =>
      tester.pumpWidget(MaterialApp(home: w));

  Color floodColor(WidgetTester tester) => tester
      .widget<Material>(
        find
            .descendant(
              of: find.byType(StudyFeedbackFlood),
              matching: find.byType(Material),
            )
            .first,
      )
      .color!;

  testWidgets('correct → teal flood + check + label', (tester) async {
    await pump(
      tester,
      const StudyFeedbackFlood(isCorrect: true, label: 'Juste !'),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Juste !'), findsOneWidget);
    expect(floodColor(tester), AppColors.feedbackCorrect);
  });

  testWidgets('wrong → orange flood + ✕ + revealed answer', (tester) async {
    await pump(
      tester,
      const StudyFeedbackFlood(
        isCorrect: false,
        label: 'À revoir',
        answer: '사과',
      ),
    );
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('사과'), findsOneWidget);
    expect(floodColor(tester), AppColors.feedbackWrong);
  });

  testWidgets('no Continuer button unless onContinue is provided', (
    tester,
  ) async {
    await pump(
      tester,
      const StudyFeedbackFlood(isCorrect: true, label: 'Juste !'),
    );
    expect(find.text('Continuer'), findsNothing);
  });

  testWidgets('Continuer button shows and fires onContinue', (tester) async {
    var tapped = false;
    await pump(
      tester,
      StudyFeedbackFlood(
        isCorrect: true,
        label: 'Juste !',
        onContinue: () => tapped = true,
      ),
    );
    expect(find.text('Continuer'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    expect(tapped, isTrue);
  });

  for (final correct in [false, true]) {
    testWidgets('feedback keyboard action and contrast (correct=$correct)', (
      tester,
    ) async {
      var continued = 0;
      await pump(
        tester,
        StudyFeedbackFlood(
          isCorrect: correct,
          label: correct ? 'Juste !' : 'À revoir',
          detail: 'Prochain rappel demain',
          onContinue: () => continued++,
        ),
      );
      await tester.pump();
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final buttonBackground = button.style!.backgroundColor!.resolve({})!;
      final buttonText = tester.widget<Text>(find.text('Continuer'));
      double ratio(Color foreground, Color background) {
        final a = foreground.computeLuminance();
        final b = background.computeLuminance();
        return ((a > b ? a : b) + 0.05) / ((a < b ? a : b) + 0.05);
      }

      expect(
        ratio(buttonText.style!.color!, buttonBackground),
        greaterThanOrEqualTo(4.5),
      );
      final detail = tester.widget<Text>(find.text('Prochain rappel demain'));
      expect(
        ratio(detail.style!.color!, floodColor(tester)),
        greaterThanOrEqualTo(4.5),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(continued, 1);
    });
  }

  testWidgets(
    'long feedback keeps Continue reachable at 320x568 and double text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var continued = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
            ),
            child: StudyFeedbackFlood(
              isCorrect: false,
              label: 'À revoir',
              answer: 'ne travaille pas / je ne travaille pas',
              answerIsKorean: false,
              detail: 'Prochain rappel dans quelques minutes',
              onContinue: () => continued = true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final button = find.byType(FilledButton);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(button);
      expect(continued, isTrue);
    },
  );
}
