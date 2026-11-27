import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/presentation/widgets/scroll_affordance.dart';

void main() {
  testWidgets(
    'cue follows async content and viewport metrics without a gesture',
    (tester) async {
      final sizes = ValueNotifier<(double, double)>((24, 160));
      addTearDown(sizes.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: sizes,
              builder: (_, value, _) => SizedBox(
                height: value.$2,
                child: ScrollAffordance(
                  hint: 'More below',
                  child: SizedBox(height: value.$1),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      double cue() =>
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
      expect(cue(), 0);
      sizes.value = (500, 160);
      await tester.pumpAndSettle();
      expect(cue(), 1);
      sizes.value = (500, 600);
      await tester.pumpAndSettle();
      expect(cue(), 0);
    },
  );

  testWidgets('announces when a reading surface continues below the fold', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 160,
            child: ScrollAffordance(
              hint: 'More below',
              child: SizedBox(height: 500),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('More below'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });
}
