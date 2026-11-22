import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/theme/app_colors.dart';
import 'package:vocab_kr/presentation/widgets/study/study_feedback_flood.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget w) =>
      tester.pumpWidget(MaterialApp(home: w));

  Color floodColor(WidgetTester tester) => tester
      .widget<Material>(find.descendant(
        of: find.byType(StudyFeedbackFlood),
        matching: find.byType(Material),
      ))
      .color!;

  testWidgets('correct → teal flood + check + label', (tester) async {
    await pump(tester,
        const StudyFeedbackFlood(isCorrect: true, label: 'Juste !'));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Juste !'), findsOneWidget);
    expect(floodColor(tester), AppColors.feedbackCorrect);
  });

  testWidgets('wrong → orange flood + ✕ + revealed answer', (tester) async {
    await pump(
      tester,
      const StudyFeedbackFlood(
          isCorrect: false, label: 'À revoir', answer: '사과'),
    );
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('사과'), findsOneWidget);
    expect(floodColor(tester), AppColors.feedbackWrong);
  });

  testWidgets('no Continuer button unless onContinue is provided',
      (tester) async {
    await pump(tester,
        const StudyFeedbackFlood(isCorrect: true, label: 'Juste !'));
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
}
