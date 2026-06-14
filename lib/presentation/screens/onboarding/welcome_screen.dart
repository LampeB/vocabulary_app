import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Icon(Icons.auto_stories, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              Text('Learn Korean\nlike you live it.',
                  style: tt.displayMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                'Audio-first vocab training with spaced repetition.\nStudy hands-free while driving.',
                style: tt.bodyLarge?.copyWith(color: AppColors.grey700),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              FilledButton(
                onPressed: () => context.go('/auth?mode=signup'),
                child: const Text('Get Started — Free'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/auth?mode=signin'),
                child: const Text('I already have an account'),
              ),
              const SizedBox(height: 24),
              Text(
                'By continuing you agree to our Terms and Privacy Policy.',
                style: tt.bodySmall?.copyWith(color: AppColors.grey500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
