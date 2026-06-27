import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../vk_waveform.dart';

/// The centerpiece of every study mode: the prompt word sitting *inside* a wide,
/// low-opacity [VkWaveform] ("word in the wave"), with an optional mono cue line
/// below.
///
/// The wave plays two roles (quiz-modes.md):
///  - **Active** ([waveActive] true) — dances on the user's turn (Voix listening,
///    Hands-free "à toi").
///  - **Ambient** ([waveActive] false) — calm, frozen brand texture behind the
///    word (Cartes / Écrire, and Hands-free while reading).
///
/// Colours are theme-aware (the word uses `onSurface`), so the same widget reads
/// correctly on the light paper and dark ink canvases.
class WordInWave extends StatelessWidget {
  const WordInWave({
    super.key,
    required this.word,
    required this.isKorean,
    this.cue,
    this.cueColor,
    this.waveActive = false,
    this.waveOpacity = 0.30,
    this.waveHeight = 140,
    this.wordSize,
  });

  /// The prompt word to display.
  final String word;

  /// Korean uses the Hangul display style; otherwise Space Grotesk.
  final bool isKorean;

  /// Optional eyebrow cue under the word (e.g. "Dis-le en coréen").
  final String? cue;

  /// Colour for the cue line. Defaults to the theme's muted tone.
  final Color? cueColor;

  /// Animate the wave (the user's turn) vs. rest it (ambient texture).
  final bool waveActive;

  /// Opacity of the waveform behind the word.
  final double waveOpacity;

  /// Height of the waveform motif.
  final double waveHeight;

  /// Optional override for the prompt word font size.
  final double? wordSize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final mutedCue = isDark ? AppColors.onDarkMuted : AppColors.muted;

    var wordStyle =
        (isKorean ? AppTextStyles.koreanPrompt : AppTextStyles.promptWord)
            .copyWith(color: cs.onSurface);
    if (wordSize != null) wordStyle = wordStyle.copyWith(fontSize: wordSize);

    return Stack(
      alignment: Alignment.center,
      children: [
        // The wave sits behind the word, slightly higher opacity on light so the
        // bars don't wash out against paper.
        Center(
          child: VkWaveform(
            height: waveHeight,
            barWidth: 12,
            gap: 10,
            opacity: isDark ? waveOpacity : waveOpacity + 0.06,
            isAnimating: waveActive,
            flatAtRest: true,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(word, style: wordStyle, textAlign: TextAlign.center),
            if (cue != null && cue!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                cue!.toUpperCase(),
                style: AppTextStyles.eyebrow.copyWith(color: cueColor ?? mutedCue),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
