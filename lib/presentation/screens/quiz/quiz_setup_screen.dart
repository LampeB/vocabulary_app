import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../../domain/entities/variant_progress.dart' show QuizDirection;
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
  QuizMode _mode      = QuizMode.voice;
  QuizDirection _dir  = QuizDirection.frToKo;
  int _cardLimit      = 20;

  static const _limits = [10, 20, 50, 100];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.ink, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Préparer la session',
            style: AppTextStyles.grotesk(22, FontWeight.w700)
                .copyWith(color: AppColors.ink)),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // ── Mode ──────────────────────────────────────────────────────
              _Section(label: 'MODE'),
              const SizedBox(height: 10),
              _ModeGrid(
                selected: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 24),
              // ── Direction ─────────────────────────────────────────────────
              _Section(label: 'SENS'),
              const SizedBox(height: 10),
              Row(
                children: [
                  _DirTile(
                    label: 'FR → KR',
                    sublabel: 'Lire en français',
                    selected: _dir == QuizDirection.frToKo,
                    accentColor: AppColors.teal,
                    onTap: () =>
                        setState(() => _dir = QuizDirection.frToKo),
                  ),
                  const SizedBox(width: 10),
                  _DirTile(
                    label: 'KR → FR',
                    sublabel: 'Lire en coréen',
                    selected: _dir == QuizDirection.koToFr,
                    accentColor: AppColors.clay,
                    onTap: () =>
                        setState(() => _dir = QuizDirection.koToFr),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ── Card count ────────────────────────────────────────────────
              _Section(label: 'CARTES PAR SESSION'),
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
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? AppColors.teal
                                : AppColors.line,
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
                            color: selected
                                ? Colors.white
                                : AppColors.muted,
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
                      Text('Démarrer la session',
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
    return Text(label,
        style: AppTextStyles.eyebrow.copyWith(color: AppColors.muted));
  }
}

// ── Mode grid ─────────────────────────────────────────────────────────────────

class _ModeGrid extends StatelessWidget {
  const _ModeGrid({required this.selected, required this.onChanged});
  final QuizMode selected;
  final ValueChanged<QuizMode> onChanged;

  static const _modes = [
    (QuizMode.voice,      Icons.mic_outlined,              'Voix',        'Prononcez la réponse'),
    (QuizMode.flashcard,  Icons.style_outlined,            'Cartes',      'Retournez les cartes'),
    (QuizMode.typing,     Icons.keyboard_outlined,         'Écrire',      'Tapez la réponse'),
    (QuizMode.handsFree,  Icons.directions_car_outlined,   'Mains libres','Mode conduite / auto'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _modes.map((m) {
        final (mode, icon, label, sublabel) = m;
        final isSelected = selected == mode;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => onChanged(mode),
            child: FrostedBox(
              borderRadius: BorderRadius.circular(16),
              borderOpacity: isSelected ? 0.0 : 0.18,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Stack(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.teal.withValues(alpha: 0.12)
                              : AppColors.line.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon,
                            color: isSelected
                                ? AppColors.teal
                                : AppColors.faint,
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
                                    .copyWith(color: AppColors.ink)),
                            Text(sublabel,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.muted)),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.teal, size: 20),
                    ],
                  ),
                  // Selection border overlay
                  if (isSelected)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.teal, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.1)
                : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accentColor : AppColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.fig(15, FontWeight.w700)
                      .copyWith(
                          color:
                              selected ? accentColor : AppColors.ink)),
              const SizedBox(height: 2),
              Text(sublabel,
                  style: AppTextStyles.captionSmall
                      .copyWith(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
