import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/notifications/notification_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          // ─── Daily reminder ───────────────────────────────────────────────
          _SectionHeader(title: 'Daily Study Reminder'),
          SwitchListTile(
            title: const Text('Daily reminder'),
            subtitle: const Text('Get a nudge to study every day'),
            value: settings.dailyReminderEnabled,
            onChanged: (v) => notifier.setDailyReminder(enabled: v),
            secondary: const Icon(Icons.alarm_outlined),
          ),
          if (settings.dailyReminderEnabled)
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Reminder time'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settings.reminderTimeLabel,
                    style: tt.titleMedium
                        ?.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: AppColors.grey500),
                ],
              ),
              onTap: () => _pickTime(context, ref, settings),
            ),
          const Divider(height: 1),

          // ─── Streak alert ─────────────────────────────────────────────────
          _SectionHeader(title: 'Streak Protection'),
          SwitchListTile(
            title: const Text('Streak warning at 8 PM'),
            subtitle:
                const Text("Alert if you haven't studied by evening"),
            value: settings.streakWarningEnabled,
            onChanged: (v) => notifier.setStreakWarning(v),
            secondary: const Icon(Icons.local_fire_department_outlined),
          ),
          const Divider(height: 1),

          // ─── Permission & test ────────────────────────────────────────────
          _SectionHeader(title: 'Permissions'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Grant notification permission'),
            subtitle: const Text('Required for all notifications'),
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.grey500),
            onTap: () async {
              final svc = ref.read(notificationServiceProvider);
              final granted = await svc.requestPermissions();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(granted
                      ? 'Notifications enabled!'
                      : 'Permission not granted — check system settings.'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('Send a test notification'),
            subtitle: const Text('Fires immediately'),
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.grey500),
            onTap: () async {
              final svc = ref.read(notificationServiceProvider);
              await svc.scheduleDailyReminder(
                  hour: DateTime.now().hour,
                  minute: (DateTime.now().minute + 1) % 60);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Test notification scheduled in ~1 min'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(
      BuildContext context, WidgetRef ref, StudyNotifSettings settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: settings.reminderHour, minute: settings.reminderMinute),
      helpText: 'Set reminder time',
    );
    if (picked == null) return;
    ref.read(notificationSettingsProvider.notifier).setDailyReminder(
          enabled: true,
          hour: picked.hour,
          minute: picked.minute,
        );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: AppColors.primary),
        ),
      );
}
