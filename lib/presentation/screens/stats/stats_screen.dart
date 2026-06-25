import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/quiz_session.dart';
import '../../providers/quiz/quiz_history_provider.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../providers/auth/auth_provider.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/frosted_box.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(quizHistoryProvider);
    final masteredAsync = ref.watch(masteredOverTimeProvider);
    final streak = ref.watch(currentUserProvider)?.currentStreak ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('stats.title'.tr()),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          historyAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: AppColors.clay, strokeWidth: 2)),
            error: (e, _) => Center(child: Text('$e')),
            data: (sessions) {
              final totalCards =
                  sessions.fold(0, (s, e) => s + e.cardCount);
              final currentMastered = sessions.isEmpty
                  ? 0
                  : sessions.first.masteredWordCount;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // ── Summary row ──────────────────────────────────────────
                  Row(
                    children: [
                      _StatChip(
                          label: 'stats.chip_sessions'.tr(),
                          value: '${sessions.length}',
                          color: AppColors.clay),
                      const SizedBox(width: 10),
                      _StatChip(
                          label: 'stats.chip_cards'.tr(),
                          value: '$totalCards',
                          color: AppColors.teal),
                      const SizedBox(width: 10),
                      _StatChip(
                          label: 'stats.chip_mastered'.tr(),
                          value: '$currentMastered',
                          color: const Color(0xFF7C5CBF)),
                      const SizedBox(width: 10),
                      _StatChip(
                          label: 'stats.chip_streak'.tr(),
                          value: '$streak j',
                          color: AppColors.rose),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Mastered words chart ──────────────────────────────────
                  _SectionLabel('stats.section_mastered_chart'.tr()),
                  const SizedBox(height: 12),
                  masteredAsync.when(
                    loading: () => const SizedBox(
                        height: 160,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.clay, strokeWidth: 2))),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (points) => _MasteredChart(points: points),
                  ),
                  const SizedBox(height: 28),

                  // ── Recent sessions ───────────────────────────────────────
                  if (sessions.isNotEmpty) ...[
                    _SectionLabel('stats.section_recent_sessions'.tr()),
                    const SizedBox(height: 12),
                    ...sessions.take(30).map((s) => _SessionTile(session: s)),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          'stats.sessions_empty'.tr(),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.muted),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Summary chip ──────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FrostedBox(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(value,
                style: AppTextStyles.grotesk(20, FontWeight.w800)
                    .copyWith(color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.eyebrowSm
                    .copyWith(color: AppColors.muted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.eyebrowSm.copyWith(color: AppColors.muted));
  }
}

// ── Mastered-over-time chart ──────────────────────────────────────────────────

class _MasteredChart extends StatelessWidget {
  const _MasteredChart({required this.points});
  final List<(DateTime, int)> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return FrostedBox(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('stats.chart_empty'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.muted)),
        ),
      );
    }

    // Build FlSpots — x = session index, y = mastered count.
    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.$2.toDouble());
    }).toList();

    final maxY = points.map((p) => p.$2).reduce((a, b) => a > b ? a : b);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = const Color(0xFF7C5CBF);
    final gridColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07);

    return FrostedBox(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (spots.length - 1).toDouble().clamp(1, double.infinity),
            minY: 0,
            maxY: (maxY * 1.2).clamp(1, double.infinity),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: ((maxY / 4).clamp(1, double.infinity)).roundToDouble(),
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: gridColor, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: ((maxY / 4).clamp(1, double.infinity)).roundToDouble(),
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: AppTextStyles.eyebrowSm
                        .copyWith(color: AppColors.muted, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: (spots.length / 4).clamp(1, double.infinity),
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                    final d = points[idx].$1;
                    return Text(
                      '${d.day}/${d.month}',
                      style: AppTextStyles.eyebrowSm
                          .copyWith(color: AppColors.muted, fontSize: 10),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: lineColor,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: spots.length <= 12,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3,
                    color: lineColor,
                    strokeColor: Colors.transparent,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      lineColor.withValues(alpha: 0.18),
                      lineColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Session tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final QuizSession session;

  IconData _modeIcon(QuizMode m) => switch (m) {
        QuizMode.voice => Icons.mic_rounded,
        QuizMode.handsFree => Icons.headphones_rounded,
        QuizMode.flashcard => Icons.style_rounded,
        QuizMode.typing => Icons.keyboard_rounded,
      };

  String _dirLabel(QuizDirectionChoice d) => switch (d) {
        QuizDirectionChoice.frToKo => 'stats.session_dir_fr_to_kr'.tr(),
        QuizDirectionChoice.koToFr => 'stats.session_dir_kr_to_fr'.tr(),
        QuizDirectionChoice.both => 'stats.session_dir_both'.tr(),
      };

  String _formatDate(DateTime d) {
    const months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
      'juil', 'août', 'sep', 'oct', 'nov', 'déc',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (session.accuracy * 100).round();
    final Color scoreColor = pct >= 80
        ? AppColors.teal
        : pct >= 50
            ? AppColors.clay
            : AppColors.rose;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FrostedBox(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Builder(builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final ink = isDark ? AppColors.onDark : AppColors.ink;
          final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;
          return Row(
            children: [
              Icon(_modeIcon(session.mode), size: 18, color: AppColors.clay),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.listName,
                        style: AppTextStyles.fig(14, FontWeight.w600)
                            .copyWith(color: ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${_dirLabel(session.direction)} · ${session.cardCount} ${'stats.session_cards_unit'.tr()} · ${_formatDate(session.completedAt)}',
                      style: AppTextStyles.caption.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('$pct %',
                  style: AppTextStyles.fig(16, FontWeight.w800)
                      .copyWith(color: scoreColor)),
            ],
          );
        }),
      ),
    );
  }
}
