import 'package:flutter/material.dart';

import 'v3_card_stack.dart';
import 'v3_pond.dart';
import 'v3_tokens.dart';

/// Full-card v3 study surface used by flashcards and hands-free mode.
/// The header counts cards remaining, not an abstract session position.
class V3StudyScaffold extends StatelessWidget {
  const V3StudyScaffold({
    required this.remaining,
    required this.onQuit,
    required this.child,
    super.key,
    this.footer,
  });

  final int remaining;
  final VoidCallback onQuit;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: V3Colors.app,
        body: V3Pond(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: onQuit,
                        tooltip: 'Quitter',
                        icon: const Icon(Icons.close_rounded,
                            color: V3Colors.inkLight),
                      ),
                      Expanded(
                        child: Center(
                          child: V3StackCounter(remaining: remaining),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(child: child),
                  if (footer != null) ...[
                    const SizedBox(height: 18),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
