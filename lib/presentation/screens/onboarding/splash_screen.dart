import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/vk_waveform.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    if (mounted) context.go(user != null ? '/home' : '/welcome');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDark,
      body: Stack(
        children: [
          const DottedGround(dark: true),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 48,
                    child: VkWaveform(isAnimating: true, opacity: 1),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'VocabKR',
                    style: AppTextStyles.grotesk(42, FontWeight.w800)
                        .copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'FR ↔ KO',
                    style: AppTextStyles.mono(14, FontWeight.w400).copyWith(
                        color: Colors.white.withValues(alpha: 0.45)),
                    letterSpacing: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
