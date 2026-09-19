import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/app_user.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/vk_waveform.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.authTimeout});

  /// Fails open to Welcome if auth restoration cannot finish. Normally the
  /// provider resolves immediately; this only prevents a permanent splash when
  /// a native or remote auth dependency is unavailable.
  final Duration? authTimeout;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _kTestMode = bool.fromEnvironment('TEST_MODE');
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  Duration get _authTimeout =>
      widget.authTimeout ??
      (_kTestMode ? const Duration(seconds: 3) : const Duration(seconds: 12));

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
    // Do not route on a timer: the destination needs a resolved auth state and,
    // for a signed-in learner, its local starter curriculum. This also keeps
    // first launch usable when the remote sync is temporarily unavailable.
    AppUser? user;
    try {
      user = await ref.read(authStateProvider.future).timeout(_authTimeout);
    } on TimeoutException {
      // The Welcome screen remains usable offline; keeping the user forever on
      // a loading screen does not make the authentication state more reliable.
      user = null;
    }
    if (user != null) {
      await ref.read(seedStarterListsProvider.future);
    }
    if (!mounted) return;
    if (mounted) context.go(user != null ? '/home' : '/welcome');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // Background from AppTheme.scaffoldBackgroundColor.
      body: Stack(
        children: [
          const DottedGround(),
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
                    'splash.appName'.tr(),
                    style: AppTextStyles.grotesk(42, FontWeight.w800)
                        .copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'splash.subtitle'.tr(),
                    style: AppTextStyles.mono(14, FontWeight.w400).copyWith(
                        color: cs.onSurface.withValues(alpha: 0.45),
                        letterSpacing: 3),
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
