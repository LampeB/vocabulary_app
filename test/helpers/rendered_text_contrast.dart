import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Keep Flutter's fallback font while async raster readback is running.
void useFallbackFontsForContrast() {
  final previous = fonts.httpClient;
  fonts.httpClient = MockClient((_) => Completer<http.Response>().future);
  addTearDown(() => fonts.httpClient = previous);
}

/// Measures the rendered text color against the whitespace just below its
/// glyph bounds. The caller chooses a label with padding on the same surface.
Future<double> renderedTextContrast(WidgetTester tester, Finder label) async {
  expect(label.hitTestable(), findsOneWidget);
  final rect = tester.getRect(label);
  final foreground = tester
      .renderObject<RenderParagraph>(label)
      .text
      .style!
      .color!;
  final view = tester.binding.renderViews.single;
  final layer = view.debugLayer! as OffsetLayer;
  return (await tester.runAsync(() async {
    final image = await layer.toImage(
      view.paintBounds,
      pixelRatio: 1 / view.flutterView.devicePixelRatio,
    );
    try {
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var minimum = double.infinity;
      for (var y = rect.bottom.ceil() + 1; y <= rect.bottom.ceil() + 3; y++) {
        for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
          final offset = (y * image.width + x) * 4;
          final background = Color.fromARGB(
            pixels.getUint8(offset + 3),
            pixels.getUint8(offset),
            pixels.getUint8(offset + 1),
            pixels.getUint8(offset + 2),
          );
          final ink = Color.alphaBlend(
            foreground,
            background,
          ).computeLuminance();
          final fill = background.computeLuminance();
          minimum = math.min(
            minimum,
            (math.max(ink, fill) + .05) / (math.min(ink, fill) + .05),
          );
        }
      }
      return minimum;
    } finally {
      image.dispose();
    }
  }))!;
}
