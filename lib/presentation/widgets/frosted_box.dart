import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Solid-fill card surface — white/95% on light, white/8% on dark.
/// No blur: BackdropFilter was removed for scroll and transition performance.
class FrostedBox extends StatelessWidget {
  const FrostedBox({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.borderOpacity = 0.18,
    this.onDark = false,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double borderOpacity;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final fill = onDark
        ? const Color(0x14FFFFFF) // white / 8 %
        : const Color(0xF2FFFFFF); // white / 95 %
    final border = onDark
        ? Color.fromRGBO(255, 255, 255, borderOpacity)
        : Color.fromRGBO(43, 38, 34, borderOpacity); // ink

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: border, width: 1),
      ),
      child: child,
    );
  }
}

/// Pill-shaped chip / button label.
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
