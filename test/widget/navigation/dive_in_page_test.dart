import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/presentation/navigation/dive_in_page.dart';

void main() {
  testWidgets('uses a spatial scale transition when motion is enabled',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          pages: [
            DiveInPage<void>(
              origin: Alignment.topCenter,
              child: const SizedBox(key: ValueKey('destination')),
            ),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    );

    expect(find.byType(ScaleTransition), findsOneWidget);
    expect(find.byKey(const ValueKey('destination')), findsOneWidget);
  });

  testWidgets('uses a fade only when motion is disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          pages: [
            DiveInPage<void>(
              disableAnimation: true,
              child: const SizedBox(key: ValueKey('destination')),
            ),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    );

    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(ScaleTransition), findsNothing);
  });
}
