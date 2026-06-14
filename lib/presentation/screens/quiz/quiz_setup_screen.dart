import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../../domain/entities/variant_progress.dart' show QuizDirection;
import '../../../core/theme/app_colors.dart';

class QuizSetupScreen extends ConsumerStatefulWidget {
  const QuizSetupScreen({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends ConsumerState<QuizSetupScreen> {
  QuizMode _mode = QuizMode.flashcard;
  QuizDirection _direction = QuizDirection.frToKo;
  int _cardLimit = 20;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Setup')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Mode', style: tt.titleMedium),
          const SizedBox(height: 8),
          _ModeSelector(
              selected: _mode,
              onChanged: (m) => setState(() => _mode = m)),
          const SizedBox(height: 24),
          Text('Direction', style: tt.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<QuizDirection>(
            segments: const [
              ButtonSegment(
                  value: QuizDirection.frToKo,
                  label: Text('FR → KO'),
                  icon: Text('🇫🇷')),
              ButtonSegment(
                  value: QuizDirection.koToFr,
                  label: Text('KO → FR'),
                  icon: Text('🇰🇷')),
            ],
            selected: {_direction},
            onSelectionChanged: (s) =>
                setState(() => _direction = s.first),
          ),
          const SizedBox(height: 24),
          Text('Cards per session', style: tt.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [10, 20, 50, 100].map((n) {
              return ChoiceChip(
                label: Text('$n'),
                selected: _cardLimit == n,
                onSelected: (_) => setState(() => _cardLimit = n),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Quiz'),
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
        direction: _direction,
        cardLimit: _cardLimit,
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onChanged});
  final QuizMode selected;
  final ValueChanged<QuizMode> onChanged;

  static const _modes = [
    (QuizMode.flashcard, Icons.style_outlined, 'Flashcard'),
    (QuizMode.typing, Icons.keyboard_outlined, 'Typing'),
    (QuizMode.voice, Icons.mic_outlined, 'Voice'),
    (QuizMode.handsFree, Icons.directions_car_outlined, 'Hands-Free'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _modes.map((m) {
        final (mode, icon, label) = m;
        final isSelected = selected == mode;
        return Card(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? const BorderSide(color: AppColors.primary, width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            onTap: () => onChanged(mode),
            leading: Icon(icon,
                color: isSelected ? AppColors.primary : AppColors.grey500),
            title: Text(label),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: AppColors.primary)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
