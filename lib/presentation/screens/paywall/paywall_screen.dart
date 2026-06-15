import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../providers/purchases/purchase_provider.dart';
import '../../../services/purchases/purchase_service.dart';
import '../../../core/theme/app_colors.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  static const _features = [
    ('ElevenLabs premium voices', Icons.record_voice_over_outlined),
    ('Voice & Hands-Free quiz mode', Icons.directions_car_outlined),
    ('Unlimited lists and words', Icons.all_inclusive),
    ('Friends & challenges', Icons.people_outlined),
    ('Leaderboards', Icons.leaderboard_outlined),
    ('Import & export', Icons.import_export_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeringsAsync = ref.watch(offeringsProvider);
    final purchaseState = ref.watch(purchaseNotifierProvider);
    final tt = Theme.of(context).textTheme;

    // Show a snackbar when any purchase/restore action errors out.
    ref.listen<AsyncValue<void>>(purchaseNotifierProvider, (prev, next) {
      if (next.hasError && prev?.hasError != true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: AppColors.secondary,
        ));
      }
    });

    final isLoading = purchaseState.isLoading;
    final offering = offeringsAsync.valueOrNull?.current;
    final monthly = offering?.monthly;
    final annual = offering?.annual;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Go Premium'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.workspace_premium,
                  size: 72, color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Unlock Everything',
                  style: tt.headlineLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Everything you need to master French and Korean.',
                style: tt.bodyMedium?.copyWith(color: AppColors.grey500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ..._features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      Icon(f.$2, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(f.$1, style: tt.bodyLarge),
                    ]),
                  )),
              const SizedBox(height: 32),
              // Purchase buttons — show skeleton while offerings load
              offeringsAsync.when(
                loading: () => const _ButtonSkeleton(),
                error: (_, __) => _FallbackButtons(isLoading: isLoading),
                data: (offerings) {
                  if (offerings == null ||
                      (monthly == null && annual == null)) {
                    return _FallbackButtons(isLoading: isLoading);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (monthly != null)
                        FilledButton(
                          onPressed: isLoading
                              ? null
                              : () => _purchase(context, ref, monthly),
                          child: Text(
                            'Start 7-day Free Trial — '
                            '${monthly.storeProduct.priceString}/mo',
                          ),
                        ),
                      if (monthly != null) const SizedBox(height: 12),
                      if (annual != null)
                        _AnnualButton(
                          package: annual,
                          enabled: !isLoading,
                          onPressed: () => _purchase(context, ref, annual),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: isLoading ? null : () => _restore(context, ref),
                child: const Text('Restore Purchase'),
              ),
              const SizedBox(height: 8),
              Text(
                'Cancel anytime · Prices vary by region\n'
                'Subscription renews automatically',
                style: tt.bodySmall?.copyWith(color: AppColors.grey500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          // Modal loading overlay during purchase / restore
          if (isLoading) ...[
            const ModalBarrier(color: Color(0x88000000), dismissible: false),
            const Center(child: CircularProgressIndicator()),
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
    if (info == null) return; // error already shown by listener
    if (PurchaseService.hasPremium(info)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase restored!')),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active purchases found.')),
      );
    }
  }
}

// Annual package button with "BEST VALUE" badge
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text('${package.storeProduct.priceString}/year'),
          ),
        ),
        Positioned(
          top: -10,
          right: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'BEST VALUE',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

// Shown while offerings are loading
class _ButtonSkeleton extends StatelessWidget {
  const _ButtonSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: null,
            child: const Text('Loading…'),
          ),
        ),
      ],
    );
  }
}

// Shown when offerings can't be loaded (network error / RC misconfigured)
class _FallbackButtons extends StatelessWidget {
  const _FallbackButtons({required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Prices unavailable — check your connection and try again.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.grey500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
