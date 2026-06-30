import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widget_keys.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/vk_waveform.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey(WidgetKeys.screenWelcome),
      // Background from AppTheme.scaffoldBackgroundColor.
      body: Stack(
        children: [
          const DottedGround(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  // ── Hero ──────────────────────────────────────────────────
                  Center(
                    child: SizedBox(
                      height: 56,
                      child: VkWaveform(isAnimating: true, opacity: 1),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'welcome.headline'.tr(),
                    style: AppTextStyles.grotesk(36, FontWeight.w700)
                        .copyWith(color: cs.onSurface, height: 1.15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'welcome.subheadline'.tr(),
                    style: AppTextStyles.fig(15, FontWeight.w400).copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(flex: 3),
                  // ── CTA buttons ───────────────────────────────────────────
                  GestureDetector(
                    onTap: () => context.go('/auth?mode=signup'),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.clay,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'welcome.cta_signup'.tr(),
                          style: AppTextStyles.fig(15, FontWeight.w700)
                              .copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.go('/auth?mode=signin'),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: cs.onSurface.withValues(alpha: 0.18)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'welcome.cta_signin'.tr(),
                          style: AppTextStyles.fig(14, FontWeight.w500)
                              .copyWith(
                                  color: cs.onSurface.withValues(alpha: 0.65)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'welcome.legal'.tr(),
                    style: AppTextStyles.captionSmall.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.28)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
