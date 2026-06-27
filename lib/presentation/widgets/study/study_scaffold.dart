import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../dotted_ground.dart';

/// The shared immersive canvas for every study mode (Voix / Cartes / Écrire /
/// Hands-free). It is the *study* surface — deliberately distinct from the
/// paper screens (Home / Lists / Start-a-session).
///
/// Theming follows the system theme (not a fixed "focus mode"): the background
/// is the theme's scaffold colour — paper `#F6F1EA` in light, deep ink
/// `#241F1B` in dark — with the dotted ground and text adapting automatically.
///
/// Layout: a minimal header (✕ quit · optional thin progress bar · counter)
/// over a full-bleed [child]. Hands-free passes [showProgress] = false so the
/// counter centres with no bar.
class StudyScaffold extends StatelessWidget {
  const StudyScaffold({
    super.key,
    required this.current,
    required this.total,
    required this.onQuit,
    required this.child,
    this.showProgress = true,
  });

  /// 1-based position of the current card.
  final int current;

  /// Total cards in the session.
  final int total;

  /// Quit the session (the ✕ button).
  final VoidCallback onQuit;

  /// The mode-specific body filling the area below the header.
  final Widget child;

  /// Show the thin progress bar between ✕ and the counter. Hands-free turns it
  /// off and centres the counter instead.
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;

    final counter =
        '${current.toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}';
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

    final counterText = Text(
      counter,
      style: AppTextStyles.mono(13, FontWeight.w700, letterSpacing: 1.5)
          .copyWith(color: muted),
    );

    return Scaffold(
      // Defaults to the theme scaffold colour (paper / deep-ink) — the study
      // canvas IS the dark theme, not a forced mode.
      body: Stack(
        children: [
          const DottedGround(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: cs.onSurface, size: 22),
                        onPressed: onQuit,
                        tooltip: 'Quitter',
                      ),
                      if (showProgress) ...[
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: cs.outline,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(cs.primary),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        counterText,
                      ] else ...[
                        Expanded(child: Center(child: counterText)),
                        // Balance the leading ✕ so the counter stays centred.
                        const SizedBox(width: 48),
                      ],
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
