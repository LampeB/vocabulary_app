import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'v3_tokens.dart';

/// The v3 pond: two barely-visible rings that drift slowly behind cards.
/// Motion is disabled when the system requests reduced motion.
class V3Pond extends StatefulWidget {
  const V3Pond({super.key, this.child});
  final Widget? child;

  @override
  State<V3Pond> createState() => _V3PondState();
}

class _V3PondState extends State<V3Pond> with TickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 46),
  )..repeat(reverse: true);
  late final AnimationController _rippleA = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 19),
  )..repeat();
  late final AnimationController _rippleB = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 23),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    _rippleA.dispose();
    _rippleB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return ColoredBox(
        color: V3Colors.app,
        child: widget.child,
      );
    }
    return ColoredBox(
      color: V3Colors.app,
      child: AnimatedBuilder(
        animation: Listenable.merge([_drift, _rippleA, _rippleB]),
        builder: (_, __) => Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(-14 * _drift.value, 10 * _drift.value),
              child: CustomPaint(
                painter: _PondPainter(_rippleA.value, _rippleB.value),
              ),
            ),
            if (widget.child != null) widget.child!,
          ],
        ),
      ),
    );
  }
}

class _PondPainter extends CustomPainter {
  const _PondPainter(this.first, this.second);
  final double first;
  final double second;

  @override
  void paint(Canvas canvas, Size size) {
    _draw(canvas, size, const Offset(.18, .30), first);
    _draw(canvas, size, const Offset(.80, .72), second);
  }

  void _draw(Canvas canvas, Size size, Offset origin, double progress) {
    final opacity = math.sin(progress * math.pi).clamp(0.0, 1.0) * .07;
    final radius = size.longestSide * (.28 + 1.37 * progress);
    canvas.drawCircle(
      Offset(size.width * origin.dx, size.height * origin.dy),
      radius,
      Paint()
        ..color = const Color(0xFFF1EDE2).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PondPainter oldDelegate) =>
      oldDelegate.first != first || oldDelegate.second != second;
}
