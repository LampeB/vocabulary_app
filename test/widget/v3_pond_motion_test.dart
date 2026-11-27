import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/presentation/widgets/v3_pond.dart' as plateau;
import 'package:vocab_kr/presentation/design/v3/v3_pond.dart' as review;

void main() {
  for (final study in [false, true]) {
    testWidgets('pond tickers follow motion settings (study=$study)', (
      tester,
    ) async {
      Future<void> show({bool reduce = false, bool visible = true}) =>
          tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduce),
                child: TickerMode(
                  enabled: visible,
                  child: study ? const review.V3Pond() : const plateau.V3Pond(),
                ),
              ),
            ),
          );
      await show(reduce: true);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await show(visible: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
      await show();
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await show(reduce: true);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await show();
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await show(visible: false);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });
  }
}
