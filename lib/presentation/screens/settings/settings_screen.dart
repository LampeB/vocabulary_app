import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../providers/purchases/purchase_provider.dart';
import '../../providers/settings/settings_provider.dart';
import '../../providers/settings/audio_settings_provider.dart';
import '../../../domain/entities/subscription_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user          = ref.watch(currentUserProvider);
    final themeMode     = ref.watch(themeModeProvider);
    final isPremium     = ref.watch(isPremiumProvider);
    final audioSettings = ref.watch(audioSettingsProvider);

    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final faint = isDark ? AppColors.onDarkFaint : AppColors.faint;

    return Scaffold(
      // Background from AppTheme.scaffoldBackgroundColor.
      appBar: AppBar(
        // AppBarTheme provides title style and icon colors.
        title: Text('settings.title'.tr()),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // ── Compte ──────────────────────────────────────────────────────
              _EyebrowSection('settings.section_account'.tr()),
              FrostedBox(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    _SmallAvatar(
                      name: user?.displayName ?? user?.username ?? '?',
                      url: user?.avatarUrl,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? user?.username ?? '—',
                            style: AppTextStyles.fig(15, FontWeight.w600)
                                .copyWith(color: cs.onSurface),
                          ),
                          Text('@${user?.username ?? ''}',
                              style: AppTextStyles.caption
                                  .copyWith(color: faint)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Apparence ───────────────────────────────────────────────────
              _EyebrowSection('settings.section_appearance'.tr()),
              FrostedBox(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.brightness_6_outlined,
                          color: muted, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('settings.theme_label'.tr(),
                          style: AppTextStyles.fig(15, FontWeight.w500)
                              .copyWith(color: cs.onSurface)),
                    ),
                    // Theme pill buttons
                    Row(
                      children: [
                        _ThemePill(
                          icon: Icons.light_mode_outlined,
                          selected: themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .set(ThemeMode.light),
                        ),
                        const SizedBox(width: 6),
                        _ThemePill(
                          icon: Icons.brightness_auto_outlined,
                          selected: themeMode == ThemeMode.system,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .set(ThemeMode.system),
                        ),
                        const SizedBox(width: 6),
                        _ThemePill(
                          icon: Icons.dark_mode_outlined,
                          selected: themeMode == ThemeMode.dark,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .set(ThemeMode.dark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Audio & Voix ─────────────────────────────────────────────────
              _EyebrowSection('settings.section_audio'.tr()),
              FrostedBox(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  children: [
                    _AudioSettingRow(
                      icon: Icons.speed_rounded,
                      label: 'settings.audio_speed_label'.tr(),
                      options: [
                        'settings.audio_speed_slow'.tr(),
                        'settings.audio_speed_normal'.tr(),
                        'settings.audio_speed_fast'.tr(),
                      ],
                      values: const [0.6, 0.85, 1.1],
                      current: audioSettings.speechRate,
                      onSelect: (v) => ref
                          .read(audioSettingsProvider.notifier)
                          .setSpeechRate(v),
                    ),
                    const SizedBox(height: 12),
                    _AudioSettingRow(
                      icon: Icons.graphic_eq_rounded,
                      label: 'settings.audio_pitch_label'.tr(),
                      options: [
                        'settings.audio_pitch_low'.tr(),
                        'settings.audio_pitch_normal'.tr(),
                        'settings.audio_pitch_high'.tr(),
                      ],
                      values: const [0.85, 1.0, 1.15],
                      current: audioSettings.pitch,
                      onSelect: (v) =>
                          ref.read(audioSettingsProvider.notifier).setPitch(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Notifications ────────────────────────────────────────────────
              _EyebrowSection('settings.section_notifications'.tr()),
              _NavTile(
                icon: Icons.notifications_outlined,
                label: 'settings.notifications_reminders'.tr(),
                onTap: () => context.push('/notifications'),
              ),
              const SizedBox(height: 24),
              // ── Abonnement ───────────────────────────────────────────────────
              _EyebrowSection('settings.section_subscription'.tr()),
              FrostedBox(
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isPremium
                            ? AppColors.clay.withValues(alpha: 0.12)
                            : cs.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.workspace_premium_outlined,
                        color: isPremium ? AppColors.clay : faint,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              isPremium
                                  ? 'settings.subscription_premium'.tr()
                                  : 'settings.subscription_free'.tr(),
                              style: AppTextStyles.fig(15, FontWeight.w500)
                                  .copyWith(color: cs.onSurface)),
                          Text(_subscriptionLabel(ref),
                              style: AppTextStyles.caption
                                  .copyWith(color: muted)),
                        ],
                      ),
                    ),
                    if (!isPremium)
                      GestureDetector(
                        onTap: () => context.push('/paywall'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.clay,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('settings.upgrade_button'.tr(),
                              style: AppTextStyles.fig(12, FontWeight.w700)
                                  .copyWith(color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Langue ───────────────────────────────────────────────────────
              _EyebrowSection('settings.section_language'.tr()),
              _NavTile(
                icon: Icons.language_rounded,
                label: 'settings.language_label'.tr(),
                subtitle: _languageName(context.locale.languageCode),
                onTap: () => _showLanguagePicker(context),
              ),
              const SizedBox(height: 24),
              // ── Compte — actions ─────────────────────────────────────────────
              _EyebrowSection('settings.section_actions'.tr()),
              _NavTile(
                icon: Icons.logout_rounded,
                label: 'settings.signout'.tr(),
                destructive: true,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.signout_dialog_title'.tr()),
        content: Text('settings.signout_dialog_body'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('settings.signout_confirm'.tr(),
                style: AppTextStyles.fig(14, FontWeight.w600)
                    .copyWith(color: AppColors.rose)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).signOut();
      if (context.mounted) context.go('/welcome');
    }
  }
}

String _languageName(String code) => switch (code) {
  'fr' => 'Français',
  'en' => 'English',
  'es' => 'Español',
  'de' => 'Deutsch',
  'it' => 'Italiano',
  'ja' => '日本語',
  'ko' => '한국어',
  _ => code,
};

void _showLanguagePicker(BuildContext context) {
  final locales = [
    const Locale('fr'),
    const Locale('en'),
    const Locale('es'),
    const Locale('de'),
    const Locale('it'),
    const Locale('ja'),
    const Locale('ko'),
  ];
  showDialog<void>(
    context: context,
    builder: (_) => SimpleDialog(
      title: Text('settings.language_label'.tr()),
      children: locales.map((locale) {
        final isSelected = context.locale == locale;
        return SimpleDialogOption(
          onPressed: () {
            context.setLocale(locale);
            Navigator.of(context).pop();
          },
          child: Row(
            children: [
              Expanded(child: Text(_languageName(locale.languageCode))),
              if (isSelected)
                const Icon(Icons.check_rounded, size: 18),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

String _subscriptionLabel(WidgetRef ref) {
  final isPremium = ref.watch(isPremiumProvider);
  if (!isPremium) return 'settings.subscription_limited'.tr();
  final type = ref.watch(currentUserProvider)?.subscriptionType;
  return type == SubscriptionType.student
      ? 'settings.subscription_student'.tr()
      : 'settings.subscription_premium_full'.tr();
}

// ── Section eyebrow ───────────────────────────────────────────────────────────

class _EyebrowSection extends StatelessWidget {
  const _EyebrowSection(this.label);
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

// ── Nav tile ──────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final faint = isDark ? AppColors.onDarkFaint : AppColors.faint;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final color = destructive ? AppColors.rose : cs.onSurface;
    final bg = destructive
        ? AppColors.rose.withValues(alpha: 0.08)
        : cs.outline.withValues(alpha: 0.3);

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
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: subtitle != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: AppTextStyles.fig(15, FontWeight.w500)
                                .copyWith(color: color)),
                        Text(subtitle!,
                            style: AppTextStyles.caption
                                .copyWith(color: muted)),
                      ],
                    )
                  : Text(label,
                      style: AppTextStyles.fig(15, FontWeight.w500)
                          .copyWith(color: color)),
            ),
            if (!destructive)
              Icon(Icons.chevron_right_rounded, color: faint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Audio setting row ─────────────────────────────────────────────────────────

class _AudioSettingRow extends StatelessWidget {
  const _AudioSettingRow({
    required this.icon,
    required this.label,
    required this.options,
    required this.values,
    required this.current,
    required this.onSelect,
  });
  final IconData icon;
  final String label;
  final List<String> options;
  final List<double> values;
  final double current;
  final ValueChanged<double> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;

    return Row(
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
          child: Text(label,
              style: AppTextStyles.fig(15, FontWeight.w500)
                  .copyWith(color: cs.onSurface)),
        ),
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _AudioPill(
                label: options[i],
                selected: (current - values[i]).abs() < 0.01,
                onTap: () => onSelect(values[i]),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AudioPill extends StatelessWidget {
  const _AudioPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final faint = isDark ? AppColors.onDarkFaint : AppColors.faint;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.teal : cs.outline,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.fig(12, FontWeight.w600)
              .copyWith(color: selected ? Colors.white : faint),
        ),
      ),
    );
  }
}

// ── Theme pill button ─────────────────────────────────────────────────────────

class _ThemePill extends StatelessWidget {
  const _ThemePill({
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final faint = isDark ? AppColors.onDarkFaint : AppColors.faint;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.teal : cs.outline,
          ),
        ),
        child: Icon(icon,
            size: 16,
            color: selected ? Colors.white : faint),
      ),
    );
  }
}

// ── Small avatar ──────────────────────────────────────────────────────────────

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.name, this.url});
  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.clay.withValues(alpha: 0.15),
      backgroundImage:
          url != null && url!.isNotEmpty ? NetworkImage(url!) : null,
      child: url == null || url!.isEmpty
          ? Text(initial,
              style: AppTextStyles.fig(16, FontWeight.w700)
                  .copyWith(color: AppColors.clayDeep))
          : null,
    );
  }
}
