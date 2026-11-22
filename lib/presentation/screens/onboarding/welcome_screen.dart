import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/v3_colors.dart';
import '../../../core/widget_keys.dart';
import '../../widgets/v3_pond.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? V3Colors.app : V3Colors.paper;
    final foreground = dark ? V3Colors.light : V3Colors.ink;
    final muted = dark ? V3Colors.light70 : V3Colors.ink60;
    final card = dark ? V3Colors.paper2 : V3Colors.paper3;
    final border = dark ? V3Colors.light60 : V3Colors.ink60;
    return Scaffold(
      key: const ValueKey(WidgetKeys.screenWelcome),
      backgroundColor: background,
      body: Stack(
        children: [
          const Positioned.fill(child: V3Pond(animate: false)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('VocabKR',
                      style: AppTextStyles.serif(29, FontWeight.w400,
                          color: foreground)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(22, 25, 22, 23),
                          decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x9914170D),
                                    blurRadius: 40,
                                    offset: Offset(0, 18))
                              ]),
                          child: Column(children: [
                            Text('APPRENDRE, À TON RYTHME',
                                style: AppTextStyles.mono(11, FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: V3Colors.terraInk)),
                            const SizedBox(height: 17),
                            Text('welcome.headline'.tr(),
                                style: AppTextStyles.serif(34, FontWeight.w400,
                                    color: V3Colors.ink),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                            Text('welcome.subheadline'.tr(),
                                style: AppTextStyles.fig(15, FontWeight.w400,
                                    height: 1.5, color: V3Colors.ink60),
                                textAlign: TextAlign.center),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => context.go('/auth?mode=signup'),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: V3Colors.terra,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                        child: Text(
                          'welcome.cta_signup'.tr(),
                          style: AppTextStyles.fig(15, FontWeight.w700)
                              .copyWith(color: V3Colors.paper),
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
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                        child: Text(
                          'welcome.cta_signin'.tr(),
                          style: AppTextStyles.fig(14, FontWeight.w500)
                              .copyWith(color: muted),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'welcome.legal'.tr(),
                    style: AppTextStyles.captionSmall.copyWith(color: muted),
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
