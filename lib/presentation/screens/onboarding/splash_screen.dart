import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/v3_colors.dart';
import '../../../domain/entities/app_user.dart';
import '../../widgets/v3_pond.dart';

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
    return Scaffold(
      backgroundColor: V3Colors.app,
      body: Stack(
        children: [
          const Positioned.fill(child: V3Pond(animate: false)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FadeTransition(
                opacity: _fade,
                child: Column(children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('VocabKR',
                        style: AppTextStyles.serif(29, FontWeight.w400,
                            color: V3Colors.light)),
                  ),
                  const Spacer(),
                  const _SplashPlateau(),
                  const Spacer(),
                  Text('On prépare tes cartes',
                      style: AppTextStyles.serif(24, FontWeight.w400,
                          color: V3Colors.light)),
                  const SizedBox(height: 7),
                  Text('Quelques secondes, puis tu pourras travailler.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.fig(14.5, FontWeight.w400,
                          color: V3Colors.light70)),
                  const SizedBox(height: 17),
                  const LinearProgressIndicator(
                    minHeight: 5,
                    value: .62,
                    backgroundColor: V3Colors.chip,
                    valueColor: AlwaysStoppedAnimation<Color>(V3Colors.amber),
                  ),
                  const SizedBox(height: 10),
                  Text('splash.subtitle'.tr(),
                      style: AppTextStyles.mono(11, FontWeight.w400,
                          letterSpacing: 1.4, color: V3Colors.light60)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashPlateau extends StatelessWidget {
  const _SplashPlateau();

  @override
  Widget build(BuildContext context) => Column(children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
                color: V3Colors.chip2, borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 126, height: 10, color: V3Colors.moss),
                    const SizedBox(height: 14),
                    Container(width: 205, height: 24, color: V3Colors.light60),
                    const SizedBox(height: 11),
                    Container(width: 170, height: 10, color: V3Colors.moss),
                    const Spacer(),
                    Container(
                        width: double.infinity,
                        height: 39,
                        color: V3Colors.moss),
                  ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(children: [
          Expanded(child: _SkeletonBlock()),
          SizedBox(width: 9),
          Expanded(child: _SkeletonBlock()),
        ]),
        const SizedBox(height: 9),
        const Row(children: [
          Expanded(child: _SkeletonBlock()),
          SizedBox(width: 9),
          Expanded(child: _SkeletonBlock()),
        ]),
      ]);
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock();
  @override
  Widget build(BuildContext context) => Container(
      height: 74,
      decoration: BoxDecoration(
          color: V3Colors.block2, borderRadius: BorderRadius.circular(13)));
}
