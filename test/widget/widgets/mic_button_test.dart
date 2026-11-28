import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/theme/app_colors.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/widgets/mic_button.dart';

void main() {
  Future<void> pumpMic(
    WidgetTester tester, {
    required bool listening,
    required QuizAnswerState answerState,
    required VoidCallback onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: MicButton(
          label: 'Activer le microphone',
          key: const Key('mic'),
          isListening: listening,
          answerState: answerState,
          onTap: onTap,
        ),
      ),
    ),
  );

  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find
                    .descendant(
                      of: find.byKey(const Key('mic')),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .decoration
          as BoxDecoration;

  Color? background(WidgetTester tester) {
    final button = tester.widget<IconButton>(find.byType(IconButton));
    return button.style!.backgroundColor!.resolve(
      button.onPressed == null ? {WidgetState.disabled} : {},
    );
  }

  testWidgets('idle microphone is tappable and starts in its resting style', (
    tester,
  ) async {
    var taps = 0;
    await pumpMic(
      tester,
      listening: false,
      answerState: QuizAnswerState.idle,
      onTap: () => taps++,
    );

    expect(find.byIcon(Icons.mic_none), findsOneWidget);
    expect(background(tester), AppColors.primary);
    expect(decoration(tester).boxShadow, isEmpty);
    await tester.tap(find.byKey(const Key('mic')));
    expect(taps, 1);
  });

  testWidgets('listening microphone pulses, glows, then resets when stopped', (
    tester,
  ) async {
    await pumpMic(
      tester,
      listening: false,
      answerState: QuizAnswerState.idle,
      onTap: () {},
    );
    await pumpMic(
      tester,
      listening: true,
      answerState: QuizAnswerState.idle,
      onTap: () {},
    );
    await tester.pump(const Duration(milliseconds: 225));

    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(background(tester), AppColors.secondary);
    expect(decoration(tester).boxShadow, hasLength(1));
    final pulsingScale = tester
        .widget<Transform>(find.byType(Transform))
        .transform
        .getMaxScaleOnAxis();
    expect(pulsingScale, greaterThan(1));

    await pumpMic(
      tester,
      listening: false,
      answerState: QuizAnswerState.idle,
      onTap: () {},
    );
    await tester.pump();
    final restingScale = tester
        .widget<Transform>(find.byType(Transform))
        .transform
        .getMaxScaleOnAxis();
    expect(restingScale, 1);
  });

  testWidgets('answer verdict changes color and prevents a second tap', (
    tester,
  ) async {
    var taps = 0;
    await pumpMic(
      tester,
      listening: true,
      answerState: QuizAnswerState.correct,
      onTap: () => taps++,
    );
    expect(background(tester), AppColors.success);
    await tester.tap(find.byKey(const Key('mic')));
    expect(taps, 0);

    await pumpMic(
      tester,
      listening: false,
      answerState: QuizAnswerState.incorrect,
      onTap: () => taps++,
    );
    expect(background(tester), AppColors.secondary);
    await tester.tap(find.byKey(const Key('mic')));
    expect(taps, 0);
  });
}
