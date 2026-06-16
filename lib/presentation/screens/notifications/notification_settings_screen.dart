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
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('Notifications',
            style: AppTextStyles.grotesk(22, FontWeight.w700)
                .copyWith(color: AppColors.ink)),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // ── Rappels quotidiens ───────────────────────────────────────────
              _Eyebrow('RAPPEL QUOTIDIEN'),
              _SwitchTile(
                icon: Icons.alarm_outlined,
                label: 'Rappel d\'étude',
                subtitle: 'Une petite piqûre de rappel chaque jour',
                value: settings.dailyReminderEnabled,
                onChanged: (v) => notifier.setDailyReminder(enabled: v),
              ),
              if (settings.dailyReminderEnabled) ...[
                const SizedBox(height: 8),
                _NavTile(
                  icon: Icons.schedule_outlined,
                  label: 'Heure du rappel',
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
              _Eyebrow('PROTECTION DE SÉRIE'),
              _SwitchTile(
                icon: Icons.local_fire_department_outlined,
                label: 'Alerte à 20h',
                subtitle: 'Si tu n\'as pas étudié avant le soir',
                value: settings.streakWarningEnabled,
                onChanged: (v) => notifier.setStreakWarning(v),
              ),
              const SizedBox(height: 24),
              // ── Permissions ──────────────────────────────────────────────────
              _Eyebrow('PERMISSIONS'),
              _NavTile(
                icon: Icons.notifications_active_outlined,
                label: 'Autoriser les notifications',
                subtitle: 'Requis pour tous les rappels',
                onTap: () async {
                  final svc = ref.read(notificationServiceProvider);
                  final granted = await svc.requestPermissions();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(granted
                          ? 'Notifications activées !'
                          : 'Permission refusée — vérifie les réglages système.'),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
              ),
              const SizedBox(height: 8),
              _NavTile(
                icon: Icons.send_outlined,
                label: 'Envoyer une notification test',
                subtitle: 'Se déclenche dans environ 1 minute',
                onTap: () async {
                  final svc = ref.read(notificationServiceProvider);
                  await svc.scheduleDailyReminder(
                    hour: DateTime.now().hour,
                    minute: (DateTime.now().minute + 1) % 60,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Notification test programmée dans ~1 min'),
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
      helpText: 'Choisir l\'heure du rappel',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label,
          style: AppTextStyles.eyebrow.copyWith(color: AppColors.muted)),
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
    return FrostedBox(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.teal.withValues(alpha: 0.12)
                  : AppColors.line.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: value ? AppColors.teal : AppColors.faint, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.fig(15, FontWeight.w500)
                        .copyWith(color: AppColors.ink)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.teal,
            thumbColor: WidgetStatePropertyAll(Colors.white),
            trackOutlineColor:
                WidgetStatePropertyAll(Colors.transparent),
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
                color: AppColors.line.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.muted, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.fig(15, FontWeight.w500)
                          .copyWith(color: AppColors.ink)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.faint, size: 20),
          ],
        ),
      ),
    );
  }
}
