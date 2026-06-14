import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class StreakCounter extends StatelessWidget {
  const StreakCounter({super.key, required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final isActive = streak > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.local_fire_department,
              color: isActive
                  ? AppColors.streakActive
                  : AppColors.streakInactive,
              size: 32,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak day${streak == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isActive
                            ? AppColors.streakActive
                            : AppColors.grey500,
                      ),
                ),
                Text(
                  isActive ? 'Keep it up!' : 'Start your streak today',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.grey500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
