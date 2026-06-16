import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// The VocabKR brand watermark — a subtle dot grid that sits behind all content
/// on every screen. It is purely decorative (IgnorePointer).
///
/// Usage: wrap any Scaffold body or Stack with this as the first child.
///
///   Stack(children: [
///     const DottedGround(),
///     // ... screen content
///   ])
///
/// Or use [DottedScaffold] for the common Scaffold+dots pattern.
class DottedGround extends StatelessWidget {
  const DottedGround({super.key, this.dark = false});

  /// True on dark (ink) backgrounds — switches to white dots at low alpha.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _DotPainter(dark: dark),
          ),
        ),
      ),
    );
  }
}

/// Convenience scaffold that already includes [DottedGround] behind its body.
class DottedScaffold extends StatelessWidget {
  const DottedScaffold({
    super.key,
    this.backgroundColor,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.resizeToAvoidBottomInset,
    this.dark = false,
  });

  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool? resizeToAvoidBottomInset;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          backgroundColor ?? (dark ? AppColors.inkDark : AppColors.paper),
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Stack(
        children: [
          DottedGround(dark: dark),
          body,
        ],
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────

class _DotPainter extends CustomPainter {
  const _DotPainter({required this.dark});
  final bool dark;

  // Dot grid: 1 px radius, 11 px pitch (matching the CSS spec).
  static const double _radius = 1.0;
  static const double _pitch  = 11.0;

  @override
  void paint(Canvas canvas, Size size) {
    final color = dark
        ? const Color(0x0DFFFFFF) // white / 5 %
        : const Color(0x1E2B2622); // ink / 12 %

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cols = (size.width  / _pitch).ceil() + 1;
    final rows = (size.height / _pitch).ceil() + 1;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(c * _pitch, r * _pitch),
          _radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.dark != dark;
}
