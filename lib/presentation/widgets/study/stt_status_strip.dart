import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/speech/stt_race_status.dart';
import '../../design/v3/v3_tokens.dart';

/// Localized words the strip needs (injected so the widget stays testable
/// without the localization runtime).
class SttStatusLabels {
  const SttStatusLabels({
    required this.engineName,
    required this.waiting,
    required this.sending,
    required this.analyzing,
    required this.empty,
    required this.failed,
    required this.offline,
    required this.noEngine,
  });

  final String Function(String engineId) engineName;
  final String waiting;
  final String sending;
  final String analyzing;
  final String empty;
  final String failed;
  final String offline;
  final String noEngine;
}

/// One chip per recognition engine active on this attempt, showing what each
/// one is doing — waiting, sending/analysing, what it heard (✓/✗), or that it
/// failed — plus an "offline" chip when cloud engines were left out. Answers
/// the learner's "is it listening, analysing, sending?" at a glance (user
/// feedback 2026-10-02).
class SttStatusStrip extends StatelessWidget {
  const SttStatusStrip({
    super.key,
    required this.status,
    required this.online,
    required this.labels,
  });

  final SttRaceStatus? status;
  final bool online;
  final SttStatusLabels labels;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? V3Colors.inkLight70 : V3Colors.ink60;
    final chips = <Widget>[
      if (!online)
        _Chip(
          icon: Icons.cloud_off_rounded,
          text: labels.offline,
          color: muted,
          dark: dark,
        ),
      if (s != null && s.engines.isEmpty && s.phase == SttPhase.done)
        _Chip(
          icon: Icons.mic_off_rounded,
          text: labels.noEngine,
          color: AppColors.feedbackWrong,
          dark: dark,
        ),
      if (s != null)
        for (final e in s.engines) _engineChip(e, muted, dark),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: chips,
    );
  }

  Widget _engineChip(SttEngineStatus e, Color muted, bool dark) {
    final name = labels.engineName(e.engineId);
    switch (e.state) {
      case SttEngineState.waiting:
        return _Chip(
            icon: e.requiresNetwork ? Icons.cloud_outlined : Icons.memory,
            text: '$name · ${labels.waiting}',
            color: muted,
            dark: dark);
      case SttEngineState.working:
        return _Chip(
            busy: true,
            text: '$name · '
                '${e.requiresNetwork ? labels.sending : labels.analyzing}',
            color: dark ? V3Colors.amber : V3Colors.terra,
            dark: dark);
      case SttEngineState.heard:
        return _Chip(
            icon: e.matched ? Icons.check_rounded : Icons.close_rounded,
            text: '$name · « ${e.transcript ?? ''} »',
            color:
                e.matched ? AppColors.feedbackCorrect : AppColors.feedbackWrong,
            dark: dark);
      case SttEngineState.empty:
        return _Chip(
            icon: Icons.hearing_disabled_rounded,
            text: '$name · ${labels.empty}',
            color: muted,
            dark: dark);
      case SttEngineState.failed:
        return _Chip(
            icon: Icons.error_outline_rounded,
            text: '$name · ${labels.failed}',
            color: muted,
            dark: dark);
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.color,
    required this.dark,
    this.icon,
    this.busy = false,
  });

  final String text;
  final Color color;
  final bool dark;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        color: color.withValues(alpha: dark ? 0.12 : 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
            )
          else if (icon != null)
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTextStyles.fig(13, FontWeight.w600).copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
