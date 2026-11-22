import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A brief, reversible page transition for an action that opens a destination.
///
/// It is deliberately a spatial suggestion rather than a card-stack effect:
/// the destination grows into place and the pop route reverses it. Callers can
/// set [origin] to the rough position of the triggering control. System
/// reduced-motion settings (and deterministic test routes) use a short fade.
class DiveInPage<T> extends CustomTransitionPage<T> {
  DiveInPage({
    required super.child,
    super.key,
    Alignment origin = Alignment.center,
    bool disableAnimation = false,
  }) : super(
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final reduceMotion =
                disableAnimation || MediaQuery.of(context).disableAnimations;
            final opacity = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            if (reduceMotion) {
              return FadeTransition(opacity: opacity, child: child);
            }

            final scale = Tween<double>(begin: 0.94, end: 1).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
            );
            return FadeTransition(
              opacity: opacity,
              child: ScaleTransition(
                alignment: origin,
                scale: scale,
                child: child,
              ),
            );
          },
        );
}
