import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';

class QuizSetupScreen extends ConsumerStatefulWidget {
  const QuizSetupScreen({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends ConsumerState<QuizSetupScreen> {
  QuizMode _mode            = QuizMode.voice;
  QuizDirectionChoice _dir  = QuizDirectionChoice.frToKo;
  int _cardLimit            = 20;

  static const _limits = [10, 20, 50, 100];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;

    return Scaffold(
      // Background from AppTheme.scaffoldBackgroundColor.
      appBar: AppBar(
        // AppBarTheme provides colors and transparent bg.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('quiz_setup.title'.tr()),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // ── Mode ──────────────────────────────────────────────────────
              _Section(label: 'quiz_setup.section_mode'.tr()),
              const SizedBox(height: 10),
              _ModeGrid(
                selected: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 24),
              // ── Direction ─────────────────────────────────────────────────
              _Section(label: 'quiz_setup.section_direction'.tr()),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DirTile(
                          label: 'quiz_setup.dir_fr_to_kr'.tr(),
                          sublabel: 'quiz_setup.dir_fr_to_kr_sub'.tr(),
                          selected: _dir == QuizDirectionChoice.frToKo,
                          accentColor: AppColors.teal,
                          onTap: () => setState(
                              () => _dir = QuizDirectionChoice.frToKo),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DirTile(
                          label: 'quiz_setup.dir_kr_to_fr'.tr(),
                          sublabel: 'quiz_setup.dir_kr_to_fr_sub'.tr(),
                          selected: _dir == QuizDirectionChoice.koToFr,
                          accentColor: AppColors.clay,
                          onTap: () => setState(
                              () => _dir = QuizDirectionChoice.koToFr),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _DirTile(
                    label: 'quiz_setup.dir_both'.tr(),
                    sublabel: 'quiz_setup.dir_both_sub'.tr(),
                    selected: _dir == QuizDirectionChoice.both,
                    accentColor: const Color(0xFF7C5CBF),
                    onTap: () =>
                        setState(() => _dir = QuizDirectionChoice.both),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ── Card count ────────────────────────────────────────────────
              _Section(label: 'quiz_setup.section_card_count'.tr()),
              const SizedBox(height: 10),
              Row(
                children: _limits.map((n) {
                  final selected = _cardLimit == n;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _cardLimit = n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.teal
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? AppColors.teal
                                : cs.outline,
                          ),
                        ),
                        child: Text(
                          '$n',
                          style: AppTextStyles.fig(
                                  14,
                                  selected
                                      ? FontWeight.w700
                                      : FontWeight.w600)
                              .copyWith(
                            color: selected ? Colors.white : muted,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              // ── Start button ──────────────────────────────────────────────
              GestureDetector(
                onTap: _start,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.clay,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text('quiz_setup.start_button'.tr(),
                          style: AppTextStyles.fig(15, FontWeight.w700)
                              .copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _start() {
    context.go(
      '/quiz',
      extra: QuizArgs(
        listId: widget.listId,
        mode: _mode,
        direction: _dir,
        cardLimit: _cardLimit,
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    return Text(label,
        style: AppTextStyles.eyebrow.copyWith(color: muted));
  }
}

// ── Mode grid ─────────────────────────────────────────────────────────────────

class _ModeGrid extends StatelessWidget {
  const _ModeGrid({required this.selected, required this.onChanged});
  final QuizMode selected;
  final ValueChanged<QuizMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
    final faint = isDark ? AppColors.onDarkFaint : AppColors.faint;

    final modes = [
      (QuizMode.voice,      Icons.mic_outlined,              'quiz_setup.mode_voice_label'.tr(),        'quiz_setup.mode_voice_sub'.tr()),
      (QuizMode.flashcard,  Icons.style_outlined,            'quiz_setup.mode_flashcard_label'.tr(),    'quiz_setup.mode_flashcard_sub'.tr()),
      (QuizMode.typing,     Icons.keyboard_outlined,         'quiz_setup.mode_typing_label'.tr(),       'quiz_setup.mode_typing_sub'.tr()),
      (QuizMode.handsFree,  Icons.directions_car_outlined,   'quiz_setup.mode_hands_free_label'.tr(),   'quiz_setup.mode_hands_free_sub'.tr()),
    ];

    return Column(
      children: modes.map((m) {
        final (mode, icon, label, sublabel) = m;
        final isSelected = selected == mode;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => onChanged(mode),
            child: Stack(
              children: [
                FrostedBox(
                  borderRadius: BorderRadius.circular(16),
                  borderOpacity: isSelected ? 0.0 : 0.18,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.teal.withValues(alpha: 0.12)
                              : cs.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon,
                            color: isSelected ? AppColors.teal : faint,
                            size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: AppTextStyles.fig(
                                        15,
                                        isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600)
                                    .copyWith(color: cs.onSurface)),
                            Text(sublabel,
                                style: AppTextStyles.caption
                                    .copyWith(color: muted)),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.teal, size: 20),
                    ],
                  ),
                ),
                // Border drawn outside FrostedBox padding so it wraps the full tile.
                if (isSelected)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.teal, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Direction tile ────────────────────────────────────────────────────────────

class _DirTile extends StatelessWidget {
  const _DirTile({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });
  final String label;
  final String sublabel;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.1)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accentColor : cs.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.fig(15, FontWeight.w700)
                      .copyWith(
                          color: selected ? accentColor : cs.onSurface)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: AppTextStyles.captionSmall
                      .copyWith(color: muted)),
            ],
          ),
        ),
      );
  }
}
