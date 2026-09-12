import 'package:flutter/material.dart';

import 'v3_tokens.dart';

/// A fixed-angle paper stack for the v3 full-card treatment.
///
/// The caller owns card advancement. This widget only renders the physical
/// state: paper edges remain behind the top card and the empty outline stays
/// visible after the last card has been removed.
class V3CardStack extends StatelessWidget {
  const V3CardStack({
    required this.child,
    required this.remaining,
    required this.total,
    super.key,
    this.maxVisibleEdges = 3,
    this.emptyLabel = 'PILE VIDE',
    this.isExiting = false,
    this.exitDirection = 1,
    this.dragProgress = 0,
    required this.cardId,
  });

  final Widget child;
  final int remaining;
  final int total;
  final int maxVisibleEdges;
  final String emptyLabel;

  /// Identity of the visible card. A new id removes the previous top card
  /// instead of reversing its exit animation with new content inside it.
  final String cardId;

  /// True while the top card is being sent away. The stack itself stays put;
  /// only this card moves, so the following card is revealed in the same spot.
  final bool isExiting;

  /// -1 for the "not yet" side, 1 for the "knew it" side.
  final int exitDirection;

  /// Horizontal position under the learner's finger, normalized to -1…1.
  final double dragProgress;

  static const _tilts = [-1.1, 1.7, -2.4, 1.2];

  @override
  Widget build(BuildContext context) {
    final edges =
        remaining <= 1 ? 0 : (remaining - 1).clamp(0, maxVisibleEdges).toInt();
    final topIndex = total <= 0
        ? 0
        : (total - remaining).clamp(0, _tilts.length - 1).toInt();
    final hasCard = remaining > 0;
    final dragTilt = dragProgress * (3.5 * 3.141592653589793 / 180);
    final exitTilt = exitDirection * (11 * 3.141592653589793 / 180);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var depth = edges; depth >= 1; depth--)
          Positioned(
            top: depth * 11,
            left: depth * 4,
            right: depth * 4,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: switch (depth) {
                  1 => V3Colors.edge1,
                  2 => V3Colors.edge2,
                  _ => V3Colors.edge3,
                },
                borderRadius: const BorderRadius.all(V3Radii.card),
              ),
            ),
          ),
        if (!hasCard)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(V3Radii.card),
                border: Border.all(
                  color: V3Colors.ruleStrong,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Text(emptyLabel, style: V3Text.mono(12)),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => Transform.translate(
              offset: Offset(dragProgress * constraints.maxWidth, 0),
              child: SizedBox.expand(
                child: AnimatedSlide(
                  key: ValueKey('v3-card-$cardId'),
                  duration: const Duration(milliseconds: 460),
                  curve: Curves.easeInCubic,
                  offset: isExiting
                      ? Offset(1.18 * exitDirection - dragProgress, 0.08)
                      : Offset.zero,
                  child: AnimatedRotation(
                    duration: const Duration(milliseconds: 460),
                    curve: Curves.easeInCubic,
                    turns: isExiting
                        ? (exitTilt - dragTilt) / (2 * 3.141592653589793)
                        : 0,
                    child: Transform.rotate(
                      angle: _tilts[topIndex] * (3.141592653589793 / 180) +
                          dragTilt,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// V3 counters describe effort remaining, never a generic position.
class V3StackCounter extends StatelessWidget {
  const V3StackCounter({required this.remaining, super.key});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final label = switch (remaining) {
      0 => 'LES CARTES SONT DÉPILÉES',
      1 => 'DERNIÈRE CARTE',
      _ => '$remaining CARTES À DÉPILER',
    };
    return Text(label, style: V3Text.mono(12, color: V3Colors.inkLight70));
  }
}
