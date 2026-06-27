import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/presentation/widgets/vk_waveform.dart';

void main() {
  Future<void> pumpWave(WidgetTester tester, Widget wave) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: wave))));

  // The 9 bar Containers live directly under the VkWaveform subtree.
  Finder bars() => find.descendant(
        of: find.byType(VkWaveform),
        matching: find.byType(Container),
      );

  testWidgets('flatAtRest collapses every bar to a uniform short line',
      (tester) async {
    await pumpWave(
      tester,
      const VkWaveform(
          isAnimating: false, flatAtRest: true, height: 100, barWidth: 8),
    );
    final n = tester.widgetList(bars()).length;
    expect(n, 9);
    for (var i = 0; i < n; i++) {
      expect(tester.getSize(bars().at(i)).height, closeTo(8, 0.5));
    }
  });

  testWidgets('frozen mountain rest keeps the mountain profile (centre tallest)',
      (tester) async {
    await pumpWave(
      tester,
      const VkWaveform(
          isAnimating: false, flatAtRest: false, height: 120, barWidth: 8),
    );
    final centre = tester.getSize(bars().at(4)).height; // middle bar
    final edge = tester.getSize(bars().at(0)).height; // first bar
    expect(centre, greaterThan(edge));
    expect(centre, greaterThan(8)); // taller than the flat baseline
  });

  testWidgets('amplitude lowers the swing vs full ripple at rest',
      (tester) async {
    await pumpWave(
      tester,
      const VkWaveform(
          isAnimating: false, amplitude: 0.3, height: 120, barWidth: 8),
    );
    final low = tester.getSize(bars().at(4)).height;

    await pumpWave(
      tester,
      const VkWaveform(
          isAnimating: false, amplitude: 1.0, height: 120, barWidth: 8),
    );
    final full = tester.getSize(bars().at(4)).height;

    expect(low, lessThan(full));
  });

  testWidgets('glow / duration params render without error', (tester) async {
    await pumpWave(
      tester,
      const VkWaveform(
        isAnimating: false,
        glow: true,
        duration: Duration(milliseconds: 700),
        height: 100,
      ),
    );
    expect(find.byType(VkWaveform), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
