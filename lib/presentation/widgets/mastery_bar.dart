import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MasteryBar extends StatelessWidget {
  const MasteryBar({super.key, required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1),
            backgroundColor: AppColors.grey300,
            valueColor: AlwaysStoppedAnimation<Color>(
              fraction >= 0.8
                  ? AppColors.success
                  : fraction >= 0.4
                      ? AppColors.warning
                      : AppColors.secondary,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(fraction * 100).round()}% mastered',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.grey500),
        ),
      ],
    );
  }
}
