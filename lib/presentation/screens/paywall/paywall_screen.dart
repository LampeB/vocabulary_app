import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../providers/purchases/purchase_provider.dart';
import '../../../services/purchases/purchase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';
import '../../widgets/vk_waveform.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  static const _featureKeys = [
    ('paywall.feature_voice', Icons.record_voice_over_outlined),
    ('paywall.feature_hands_free', Icons.directions_car_outlined),
    ('paywall.feature_unlimited', Icons.all_inclusive),
    ('paywall.feature_social', Icons.people_outlined),
    ('paywall.feature_leaderboard', Icons.leaderboard_outlined),
    ('paywall.feature_import_export', Icons.import_export_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeringsAsync = ref.watch(offeringsProvider);
    final purchaseState = ref.watch(purchaseNotifierProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final faint = isDark ? AppColors.onDarkFaint : AppColors.faint;

    ref.listen<AsyncValue<void>>(purchaseNotifierProvider, (prev, next) {
      if (next.hasError && prev?.hasError != true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('paywall.error_purchase'.tr()),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });

    final isLoading = purchaseState.isLoading;
    final offering  = offeringsAsync.valueOrNull?.current;
    final monthly   = offering?.monthly;
    final annual    = offering?.annual;

    return Scaffold(
      // Background from AppTheme.scaffoldBackgroundColor.
      appBar: AppBar(
        // AppBarTheme provides transparent bg; override icon to semi-muted.
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: cs.onSurface.withValues(alpha: 0.5), size: 22),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          // Waveform watermark
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: Opacity(
              opacity: 0.06,
              child: VkWaveform(isAnimating: true, opacity: 1),
            ),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            children: [
              const SizedBox(height: 16),
              // ── Hero ───────────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.clay.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.clay.withValues(alpha: 0.4),
                        width: 1.5),
                  ),
                  child: const Icon(Icons.workspace_premium_outlined,
                      color: AppColors.clay, size: 36),
                ),
              ),
              const SizedBox(height: 20),
              Text('paywall.title'.tr(),
                  style: AppTextStyles.grotesk(32, FontWeight.w700)
                      .copyWith(color: cs.onSurface),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'paywall.subtitle'.tr(),
                style: AppTextStyles.fig(15, FontWeight.w400)
                    .copyWith(color: muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // ── Feature list ───────────────────────────────────────────────
              ..._featureKeys.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.clay.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(f.$2,
                              color: AppColors.clay, size: 17),
                        ),
                        const SizedBox(width: 14),
                        Text(f.$1.tr(),
                            style: AppTextStyles.fig(15, FontWeight.w500)
                                .copyWith(color: cs.onSurface)),
                      ],
                    ),
                  )),
              const SizedBox(height: 36),
              // ── Purchase buttons ───────────────────────────────────────────
              offeringsAsync.when(
                loading: () => const _ButtonSkeleton(),
                error: (_, __) => _FallbackMessage(muted: muted),
                data: (offerings) {
                  if (offerings == null ||
                      (monthly == null && annual == null)) {
                    return _FallbackMessage(muted: muted);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (annual != null) ...[
                        _AnnualButton(
                          package: annual,
                          enabled: !isLoading,
                          onPressed: () => _purchase(context, ref, annual),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (monthly != null)
                        _MonthlyButton(
                          package: monthly,
                          enabled: !isLoading,
                          onPressed: () => _purchase(context, ref, monthly),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: isLoading ? null : () => _restore(context, ref),
                  child: Text('paywall.restore'.tr(),
                      style: AppTextStyles.fig(13, FontWeight.w500)
                          .copyWith(color: faint)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'paywall.legal'.tr(),
                style: AppTextStyles.captionSmall.copyWith(color: faint),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          // Modal loading overlay
          if (isLoading) ...[
            const ModalBarrier(
                color: Color(0x88000000), dismissible: false),
            const Center(
                child: CircularProgressIndicator(color: AppColors.clay)),
          ],
        ],
      ),
    );
  }

  Future<void> _purchase(
      BuildContext context, WidgetRef ref, Package package) async {
    final ok =
        await ref.read(purchaseNotifierProvider.notifier).purchase(package);
    if (ok && context.mounted) context.pop();
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final info =
        await ref.read(purchaseNotifierProvider.notifier).restore();
    if (!context.mounted) return;
    if (info == null) return;
    if (PurchaseService.hasPremium(info)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('paywall.restore_success'.tr()),
            behavior: SnackBarBehavior.floating),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('paywall.restore_none'.tr()),
            behavior: SnackBarBehavior.floating),
      );
    }
  }
}

// ── Annual button (highlighted) ───────────────────────────────────────────────

class _AnnualButton extends StatelessWidget {
  const _AnnualButton({
    required this.package,
    required this.enabled,
    required this.onPressed,
  });
  final Package package;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final price = package.storeProduct.priceString;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: enabled ? onPressed : null,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.clay,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'paywall.annual_button'.tr(namedArgs: {'price': price}),
                  style: AppTextStyles.fig(14, FontWeight.w700)
                      .copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        // Badge
        Positioned(
          top: -10,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('paywall.annual_badge'.tr(),
                style: AppTextStyles.eyebrow
                    .copyWith(color: Colors.white, fontSize: 9)),
          ),
        ),
      ],
    );
  }
}

// ── Monthly button (ghost) ────────────────────────────────────────────────────

class _MonthlyButton extends StatelessWidget {
  const _MonthlyButton({
    required this.package,
    required this.enabled,
    required this.onPressed,
  });
  final Package package;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final price = package.storeProduct.priceString;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: FrostedBox(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'paywall.monthly_button'.tr(namedArgs: {'price': price}),
            style: AppTextStyles.fig(14, FontWeight.w500)
                .copyWith(color: muted),
          ),
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _ButtonSkeleton extends StatelessWidget {
  const _ButtonSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 56,
      child: Center(
          child: CircularProgressIndicator(color: AppColors.clay)),
    );
  }
}

// ── Fallback when offerings fail ──────────────────────────────────────────────

class _FallbackMessage extends StatelessWidget {
  const _FallbackMessage({required this.muted});
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'paywall.offerings_unavailable'.tr(),
        style: AppTextStyles.fig(14, FontWeight.w400).copyWith(color: muted),
        textAlign: TextAlign.center,
      ),
    );
  }
}
