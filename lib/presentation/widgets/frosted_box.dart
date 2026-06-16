import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Frosted glass surface — white/50 % fill, blur(6), 1 px ink/18 % border.
/// No shadow; intentionally flat so the dotted ground reads through.
///
/// Use for: secondary buttons, bottom nav, list cards, "Réécouter" pill,
/// info chips, and any frosted control in the design spec.
class FrostedBox extends StatelessWidget {
  const FrostedBox({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.blur = 6.0,
    this.fillOpacity = 0.5,
    this.borderOpacity = 0.18,
    this.onDark = false,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Backdrop blur sigma — 6 for controls, 14 for bottom nav.
  final double blur;

  /// White fill opacity.
  final double fillOpacity;

  /// Border ink (or white-on-dark) opacity.
  final double borderOpacity;

  /// True when placed on an ink/dark background (switches to white tones).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final fill = onDark
        ? Color.fromRGBO(255, 255, 255, fillOpacity * 0.3)
        : Color.fromRGBO(255, 255, 255, fillOpacity);
    final border = onDark
        ? Color.fromRGBO(255, 255, 255, borderOpacity)
        : Color.fromRGBO(43, 38, 34, borderOpacity); // ink

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(color: border, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Pill-shaped frosted chip / button label.
class FrostedPill extends StatelessWidget {
  const FrostedPill({
    super.key,
    required this.child,
    this.onDark = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  final Widget child;
  final bool onDark;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return FrostedBox(
      borderRadius: BorderRadius.circular(999),
      padding: padding,
      onDark: onDark,
      child: child,
    );
  }
}
