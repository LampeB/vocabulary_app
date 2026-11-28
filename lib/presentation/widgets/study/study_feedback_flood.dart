import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widget_keys.dart';
import '../scroll_affordance.dart';

/// The unified grading feedback used by every study mode: a held, **full-screen
/// colour flood** (not a tint) so it's catchable peripherally — bright teal for
/// "Juste !", bright orange for "À revoir" — with a contrasted icon and label.
///
/// Theme-independent by design (the floods are identical in light and dark).
/// Generalises the old per-screen `_triggerFlash` / `_AnswerFeedback`.
///
/// - Tap modes (Voix / Cartes / Écrire) pass [onContinue] to show a Continuer
///   button and advance manually.
/// - Hands-free passes [onContinue] = null — a transient flood that the screen
///   dismisses on its own timer.
class StudyFeedbackFlood extends StatelessWidget {
  const StudyFeedbackFlood({
    super.key,
    required this.isCorrect,
    required this.label,
    this.answer,
    this.answerIsKorean = true,
    this.detail,
    this.continueLabel,
    this.onContinue,
    this.onPlayAudio,
  });

  /// Correct → teal flood + check; wrong → orange flood + ✕.
  final bool isCorrect;

  /// Headline, e.g. "Juste !" / "À revoir" (already localised by the caller).
  final String label;

  /// The revealed answer (shown especially on a wrong answer).
  final String? answer;

  /// Render [answer] with the Hangul display style vs Space Grotesk.
  final bool answerIsKorean;

  /// Optional secondary line, e.g. the next-review interval.
  final String? detail;

  /// Continuer button text (defaults to "Continuer"). Only shown if [onContinue].
  final String? continueLabel;

  /// When non-null, show a Continuer button that calls this; otherwise the flood
  /// is transient (hands-free dismisses it itself).
  final VoidCallback? onContinue;

  /// When non-null, a speaker button plays the answer audio on demand
  /// (replaces auto-play so a fast Continuer can't overlap audio).
  final VoidCallback? onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect
        ? AppColors.feedbackCorrect
        : AppColors.feedbackWrong;

    return Material(
      key: ValueKey(
        isCorrect ? WidgetKeys.feedbackCorrect : WidgetKeys.feedbackWrong,
      ),
      color: color,
      child: SafeArea(
        child: ScrollAffordance(
          hint: 'v3.scroll_hint'.tr(),
          fillViewport: true,
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCorrect ? Icons.check_rounded : Icons.close_rounded,
                  color: AppColors.ink,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.grotesk(
                  28,
                  FontWeight.w700,
                ).copyWith(color: AppColors.ink),
              ),
              if (answer != null && answer!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  answer!,
                  textAlign: TextAlign.center,
                  style:
                      (answerIsKorean
                              ? AppTextStyles.koreanPrompt.copyWith(
                                  fontSize: 40,
                                )
                              : AppTextStyles.grotesk(40, FontWeight.w700))
                          .copyWith(color: AppColors.ink),
                ),
                if (onPlayAudio != null) ...[
                  const SizedBox(height: 8),
                  IconButton(
                    key: const ValueKey(WidgetKeys.feedbackPlayAudio),
                    onPressed: onPlayAudio,
                    iconSize: 32,
                    icon: const Icon(
                      Icons.volume_up_rounded,
                      color: AppColors.ink,
                    ),
                    tooltip: 'quiz.play_audio'.tr(),
                  ),
                ],
              ],
              if (detail != null && detail!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.fig(
                    14,
                    FontWeight.w500,
                  ).copyWith(color: AppColors.ink),
                ),
              ],
              const Spacer(),
              if (onContinue != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey(WidgetKeys.feedbackContinue),
                    autofocus: true,
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      continueLabel ?? 'course.continue'.tr(),
                      style: AppTextStyles.fig(
                        16,
                        FontWeight.w700,
                      ).copyWith(color: AppColors.ink),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
