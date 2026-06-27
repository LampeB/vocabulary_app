import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// The unified grading feedback used by every study mode: a held, **full-screen
/// colour flood** (not a tint) so it's catchable peripherally — bright teal for
/// "Juste !", bright orange for "À revoir" — with a big white icon and label.
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

  @override
  Widget build(BuildContext context) {
    final color =
        isCorrect ? AppColors.feedbackCorrect : AppColors.feedbackWrong;

    return Material(
      color: color,
      child: SafeArea(
        child: Padding(
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
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.grotesk(28, FontWeight.w700)
                    .copyWith(color: Colors.white),
              ),
              if (answer != null && answer!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  answer!,
                  textAlign: TextAlign.center,
                  style: (answerIsKorean
                          ? AppTextStyles.koreanPrompt.copyWith(fontSize: 40)
                          : AppTextStyles.grotesk(40, FontWeight.w700))
                      .copyWith(color: Colors.white),
                ),
              ],
              if (detail != null && detail!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.fig(14, FontWeight.w500)
                      .copyWith(color: Colors.white.withValues(alpha: 0.92)),
                ),
              ],
              const Spacer(),
              if (onContinue != null)
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: onContinue,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          continueLabel ?? 'Continuer',
                          style: AppTextStyles.fig(16, FontWeight.w700)
                              .copyWith(color: color),
                        ),
                      ),
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
