import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Go Premium')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.workspace_premium,
                size: 72, color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Unlock everything',
                style: tt.headlineLarge, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ...[
              ('ElevenLabs premium voices', Icons.record_voice_over_outlined),
              ('Voice & Hands-Free quiz mode', Icons.directions_car_outlined),
              ('Unlimited lists and words', Icons.all_inclusive),
              ('Friends & challenges', Icons.people_outlined),
              ('Leaderboards', Icons.leaderboard_outlined),
              ('Import & export', Icons.import_export_outlined),
            ].map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(f.$2, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text(f.$1, style: tt.bodyLarge),
                    ],
                  ),
                )),
            const Spacer(),
            FilledButton(
              onPressed: () {},
              child: const Text('Start 7-day Free Trial — €4.99/mo'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('€29.99/year (save 50%)'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {},
              child: const Text('Restore Purchase'),
            ),
          ],
        ),
      ),
    );
  }
}
