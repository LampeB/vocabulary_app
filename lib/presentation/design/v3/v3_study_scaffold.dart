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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? V3Colors.inkLight : V3Colors.ink;
    return Scaffold(
      backgroundColor: dark ? V3Colors.app : V3Colors.paper,
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
                      icon: Icon(Icons.close_rounded, color: foreground),
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
}
