import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/vk_waveform.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDark,
      body: Stack(
        children: [
          const DottedGround(dark: true),
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
                    'Apprends le coréen\ncomme tu le vis.',
                    style: AppTextStyles.grotesk(36, FontWeight.w700)
                        .copyWith(
                            color: Colors.white, height: 1.15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Entraînement audio avec répétition espacée.\nÉtudie en voiture, sans regarder l\'écran.',
                    style: AppTextStyles.fig(15, FontWeight.w400).copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
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
                          'Commencer gratuitement',
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
                            color: Colors.white.withValues(alpha: 0.18)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'J\'ai déjà un compte',
                          style: AppTextStyles.fig(14, FontWeight.w500)
                              .copyWith(
                                  color:
                                      Colors.white.withValues(alpha: 0.65)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'En continuant, tu acceptes nos Conditions d\'utilisation\net notre Politique de confidentialité.',
                    style: AppTextStyles.captionSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.28)),
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
