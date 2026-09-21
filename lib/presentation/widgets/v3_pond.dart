import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/v3_colors.dart';

/// The quiet V3 water layer. It deliberately has no semantic content and is
/// removed for users who request reduced motion.
class V3Pond extends StatefulWidget {
  const V3Pond({super.key});

  @override
  State<V3Pond> createState() => _V3PondState();
}

class _V3PondState extends State<V3Pond> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 23),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.expand();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _PondPainter(_controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PondPainter extends CustomPainter {
  const _PondPainter(this.time);
  final double time;

  static const _grid = <Offset>[
    Offset(.12, .12),
    Offset(.52, .12),
    Offset(.88, .12),
    Offset(.32, .32),
    Offset(.72, .32),
    Offset(.12, .52),
    Offset(.52, .52),
    Offset(.88, .52),
    Offset(.32, .72),
    Offset(.72, .72),
    Offset(.12, .84),
    Offset(.88, .84),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Three independent "fish" groups. Each group emits 3–5 rings at one
    // grid intersection, fades, then picks another non-neighbouring point.
    for (var source = 0; source < 3; source++) {
      final phase = (time * 1.45 + source * .31) % 1;
      final batch = (time * 1.45 + source * .31).floor();
      final origin = _originFor(source, batch, size);
      final ringCount = 3 + ((batch + source) % 3);
      for (var ring = 0; ring < ringCount; ring++) {
        final ringPhase = phase - ring * .115;
        if (ringPhase < 0 || ringPhase > .72) continue;
        final fade = math.sin(ringPhase / .72 * math.pi) * .10;
        paint.color = V3Colors.light.withValues(alpha: fade);
        final radius = 16 + ringPhase / .72 * size.longestSide * .58;
        canvas.drawCircle(origin, radius, paint);
      }
    }
  }

  Offset _originFor(int source, int batch, Size size) {
    // The strides choose separate points in the grid. The adjacent-source
    // offset is deliberately large enough to keep focal points apart.
    final index = (batch * 5 + source * 4) % _grid.length;
    final point = _grid[index];
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  @override
  bool shouldRepaint(_PondPainter oldDelegate) => oldDelegate.time != time;
}
