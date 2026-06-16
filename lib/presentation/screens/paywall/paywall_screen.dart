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

  static const _features = [
    ('Voix premium ElevenLabs', Icons.record_voice_over_outlined),
    ('Mode voix & mains libres', Icons.directions_car_outlined),
    ('Listes et mots illimités', Icons.all_inclusive),
    ('Amis & défis', Icons.people_outlined),
    ('Classements', Icons.leaderboard_outlined),
    ('Import & export', Icons.import_export_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeringsAsync = ref.watch(offeringsProvider);
    final purchaseState = ref.watch(purchaseNotifierProvider);

    ref.listen<AsyncValue<void>>(purchaseNotifierProvider, (prev, next) {
      if (next.hasError && prev?.hasError != true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Une erreur est survenue. Réessaie.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });

    final isLoading = purchaseState.isLoading;
    final offering  = offeringsAsync.valueOrNull?.current;
    final monthly   = offering?.monthly;
    final annual    = offering?.annual;

    return Scaffold(
      backgroundColor: AppColors.inkDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          const DottedGround(dark: true),
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
              Text('Tout débloquer',
                  style: AppTextStyles.grotesk(32, FontWeight.w700)
                      .copyWith(color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Tout ce qu\'il faut pour maîtriser le coréen.',
                style:
                    AppTextStyles.fig(15, FontWeight.w400).copyWith(
                        color: Colors.white.withValues(alpha: 0.55)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // ── Feature list ───────────────────────────────────────────────
              ..._features.map((f) => Padding(
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
                        Text(f.$1,
                            style: AppTextStyles.fig(15, FontWeight.w500)
                                .copyWith(color: Colors.white)),
                      ],
                    ),
                  )),
              const SizedBox(height: 36),
              // ── Purchase buttons ───────────────────────────────────────────
              offeringsAsync.when(
                loading: () => const _ButtonSkeleton(),
                error: (_, __) => _FallbackMessage(isLoading: isLoading),
                data: (offerings) {
                  if (offerings == null ||
                      (monthly == null && annual == null)) {
                    return _FallbackMessage(isLoading: isLoading);
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
                  child: Text('Restaurer un achat',
                      style: AppTextStyles.fig(13, FontWeight.w500)
                          .copyWith(
                              color: Colors.white.withValues(alpha: 0.45))),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Résiliable à tout moment · Prix selon la région\n'
                'Renouvellement automatique',
                style: AppTextStyles.captionSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.3)),
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
        const SnackBar(
            content: Text('Achat restauré !'),
            behavior: SnackBarBehavior.floating),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucun achat actif trouvé.'),
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
                  'Essai 7 jours gratuits — '
                  '${package.storeProduct.priceString}/an',
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
            child: Text('MEILLEUR PRIX',
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
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: FrostedBox(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '${package.storeProduct.priceString}/mois — sans engagement',
            style: AppTextStyles.fig(14, FontWeight.w500)
                .copyWith(color: Colors.white.withValues(alpha: 0.7)),
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
  const _FallbackMessage({required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Prix indisponibles — vérifie ta connexion et réessaie.',
        style: AppTextStyles.fig(14, FontWeight.w400)
            .copyWith(color: Colors.white.withValues(alpha: 0.45)),
        textAlign: TextAlign.center,
      ),
    );
  }
}
