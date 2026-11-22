import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/presentation/widgets/scroll_affordance.dart';

void main() {
  testWidgets('announces when a reading surface continues below the fold',
      (tester) async {
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
