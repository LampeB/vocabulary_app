import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/notifications/notification_provider.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Scaffold(
      // Background from AppTheme.scaffoldBackgroundColor.
      appBar: AppBar(
        // AppBarTheme provides title style and icon colors.
        title: Text('notifications.title'.tr()),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // ── Rappels quotidiens ───────────────────────────────────────────
              _Eyebrow('notifications.section_daily'.tr()),
              _SwitchTile(
                icon: Icons.alarm_outlined,
                label: 'notifications.daily_reminder_label'.tr(),
                subtitle: 'notifications.daily_reminder_subtitle'.tr(),
                value: settings.dailyReminderEnabled,
                onChanged: (v) => notifier.setDailyReminder(enabled: v),
              ),
              if (settings.dailyReminderEnabled) ...[
                const SizedBox(height: 8),
                _NavTile(
                  icon: Icons.schedule_outlined,
                  label: 'notifications.reminder_time_label'.tr(),
                  trailing: Text(
                    settings.reminderTimeLabel,
                    style: AppTextStyles.fig(14, FontWeight.w600)
                        .copyWith(color: AppColors.teal),
                  ),
                  onTap: () => _pickTime(context, ref, settings),
                ),
              ],
              const SizedBox(height: 24),
              // ── Protection de série ──────────────────────────────────────────
              _Eyebrow('notifications.section_streak'.tr()),
              _SwitchTile(
                icon: Icons.local_fire_department_outlined,
                label: 'notifications.streak_warning_label'.tr(),
                subtitle: 'notifications.streak_warning_subtitle'.tr(),
                value: settings.streakWarningEnabled,
                onChanged: (v) => notifier.setStreakWarning(v),
              ),
              const SizedBox(height: 24),
              // ── Permissions ──────────────────────────────────────────────────
              _Eyebrow('notifications.section_permissions'.tr()),
              _NavTile(
                icon: Icons.notifications_active_outlined,
                label: 'notifications.permission_label'.tr(),
                subtitle: 'notifications.permission_subtitle'.tr(),
                onTap: () async {
                  final svc = ref.read(notificationServiceProvider);
                  final granted = await svc.requestPermissions();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(granted
                          ? 'notifications.permission_granted'.tr()
                          : 'notifications.permission_denied'.tr()),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
              ),
              const SizedBox(height: 8),
              _NavTile(
                icon: Icons.send_outlined,
                label: 'notifications.test_label'.tr(),
                subtitle: 'notifications.test_subtitle'.tr(),
                onTap: () async {
                  final svc = ref.read(notificationServiceProvider);
                  await svc.scheduleDailyReminder(
                    hour: DateTime.now().hour,
                    minute: (DateTime.now().minute + 1) % 60,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('notifications.test_scheduled'.tr()),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref,
      StudyNotifSettings settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: settings.reminderHour, minute: settings.reminderMinute),
      helpText: 'notifications.time_picker_help'.tr(),
    );
    if (picked == null) return;
    ref.read(notificationSettingsProvider.notifier).setDailyReminder(
          enabled: true,
          hour: picked.hour,
          minute: picked.minute,
        );
  }
}

// ── Eyebrow label ─────────────────────────────────────────────────────────────

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label,
          style: AppTextStyles.eyebrow.copyWith(color: muted)),
    );
  }
}

// ── Switch tile ───────────────────────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final faint = isDark ? AppColors.onDarkFaint : AppColors.faint;
    final iconBg = value
        ? AppColors.teal.withValues(alpha: 0.12)
        : cs.outline.withValues(alpha: 0.3);

    return FrostedBox(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: value ? AppColors.teal : faint, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.fig(15, FontWeight.w500)
                        .copyWith(color: cs.onSurface)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: AppTextStyles.caption
                          .copyWith(color: muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.teal,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackOutlineColor:
                const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final faint = isDark ? AppColors.onDarkFaint : AppColors.faint;

    return GestureDetector(
      onTap: onTap,
      child: FrostedBox(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: muted, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.fig(15, FontWeight.w500)
                          .copyWith(color: cs.onSurface)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: AppTextStyles.caption
                            .copyWith(color: muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: faint, size: 20),
          ],
        ),
      ),
    );
  }
}
