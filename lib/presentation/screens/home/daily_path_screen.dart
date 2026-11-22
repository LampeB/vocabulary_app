import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/v3_colors.dart';
import '../../../core/widget_keys.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../../domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import '../../providers/lists/vocabulary_provider.dart';
import '../../providers/quiz/quiz_provider.dart';
import '../../providers/settings/default_pair_provider.dart';
import '../../widgets/v3_pond.dart';

/// A short ordered V3 trail. It recommends today's next card without
/// removing independent practice from the rest of the app.
class DailyPathScreen extends ConsumerWidget {
  const DailyPathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pair = ref.watch(defaultPairProvider);
    final due = ref.watch(dueCountForPairProvider(pair));
    final lists =
        ref.watch(myListsProvider).valueOrNull ?? const <VocabularyList>[];
    final matching =
        lists.where((list) => list.langA == pair.$1 && list.langB == pair.$2);
    final prerequisite = matching.isEmpty
        ? (lists.isEmpty ? null : lists.first)
        : matching.first;

    return Scaffold(
      key: const ValueKey(WidgetKeys.screenDailyPath),
      backgroundColor: V3Colors.app,
      body: Stack(children: [
        const Positioned.fill(child: V3Pond(animate: false)),
        SafeArea(
          child: due.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: V3Colors.amber)),
            error: (_, __) => _DailyTrail(
                pair: pair, dueCount: 0, prerequisite: prerequisite),
            data: (count) => _DailyTrail(
                pair: pair, dueCount: count, prerequisite: prerequisite),
          ),
        ),
      ]),
    );
  }
}

class _DailyTrail extends StatelessWidget {
  const _DailyTrail({
    required this.pair,
    required this.dueCount,
    required this.prerequisite,
  });

  final (String, String) pair;
  final int dueCount;
  final VocabularyList? prerequisite;

  @override
  Widget build(BuildContext context) {
    final reviewDone = dueCount == 0;
    final completed = reviewDone ? 1 : 0;
    final activeTitle = reviewDone
        ? prerequisite == null
            ? 'Préparer une première liste'
            : '${prerequisite!.wordCount.clamp(1, 7)} nouveaux mots'
        : '$dueCount ${dueCount == 1 ? 'mot à revoir' : 'mots à revoir'}';
    final activeSubtitle = reviewDone
        ? prerequisite == null
            ? 'Quelques mots suffisent pour commencer'
            : 'Liste «\u202f${prerequisite!.name}\u202f» · environ 4 minutes'
        : 'Reprends les mots qui t’attendent';

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 650;
      final activeTop = compact ? 160.0 : 180.0;
      final followTop = compact ? 360.0 : 405.0;
      final lessonTop = compact ? 455.0 : 515.0;
      return Stack(children: [
        const Positioned.fill(child: _TrailLine()),
        Positioned(
          left: 16,
          right: 16,
          top: 8,
          child: Row(children: [
            _BackButton(onTap: () => context.pop()),
            const SizedBox(width: 13),
            Expanded(
              child: Text('TES CARTES DU JOUR',
                  style: AppTextStyles.mono(12, FontWeight.w400,
                      letterSpacing: 1.1, color: V3Colors.light60)),
            ),
            Text('$completed / 4',
                style: AppTextStyles.mono(12, FontWeight.w400,
                    color: V3Colors.amber)),
          ]),
        ),
        Positioned(
          left: 20,
          top: 65,
          width: 182,
          child: _TrailCard(
            key: const ValueKey(WidgetKeys.dailyPathReview),
            label: reviewDone ? '✓ RÉVISER' : 'À TOI · RÉVISER',
            title: reviewDone
                ? 'Révisions terminées'
                : '$dueCount ${dueCount == 1 ? 'mot' : 'mots'} à revoir',
            active: !reviewDone,
            done: reviewDone,
            onTap: reviewDone ? null : () => _showModes(context),
          ),
        ),
        Positioned(
          left: 26,
          right: 20,
          top: activeTop,
          child: _ActiveCard(
            label: reviewDone ? 'À TOI · DÉCOUVRIR' : 'À TOI · RÉVISER',
            title: activeTitle,
            subtitle: activeSubtitle,
            cta: reviewDone ? 'Prendre la carte' : 'Choisir le mode',
            onTap: reviewDone
                ? () => prerequisite == null
                    ? context.go('/lists')
                    : context.push('/lists/${prerequisite!.id}')
                : () => _showModes(context),
          ),
        ),
        Positioned(
          left: 22,
          top: followTop,
          width: 212,
          child: _TrailCard(
            key: const ValueKey(WidgetKeys.dailyPathPractice),
            label: reviewDone ? 'À TOI · DÉCOUVRIR' : 'PUIS · DÉCOUVRIR',
            title: prerequisite?.name ?? 'Ta première liste',
            active: reviewDone,
            onTap: reviewDone
                ? () => prerequisite == null
                    ? context.go('/lists')
                    : context.push('/lists/${prerequisite!.id}')
                : null,
          ),
        ),
        Positioned(
          right: 20,
          top: lessonTop,
          width: 218,
          child: _TrailCard(
            key: const ValueKey(WidgetKeys.dailyPathLessons),
            label: 'PUIS · LIRE',
            title: 'Une leçon à découvrir',
            onTap: () => context.push('/grammar'),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _TrailProgress(completed: completed),
        ),
      ]);
    });
  }

  void _showModes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (sheetContext) => _ModeSheet(
        onSelected: (mode) {
          Navigator.pop(sheetContext);
          context.push('/quiz',
              extra: QuizArgs(
                source: QuizSource.allDue,
                mode: mode,
                direction: QuizDirectionChoice.both,
                cardLimit: const int.fromEnvironment('TEST_CARD_LIMIT',
                    defaultValue: 20),
                langA: pair.$1,
                langB: pair.$2,
              ));
        },
      ),
    );
  }
}

class _TrailLine extends StatelessWidget {
  const _TrailLine();
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(size: Size.infinite, painter: _TrailLinePainter()),
      );
}

class _TrailLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF64705F)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .29, 130)
      ..lineTo(size.width * .42, 184)
      ..lineTo(size.width * .36, 362)
      ..lineTo(size.width * .56, 435)
      ..lineTo(size.width * .44, 520);
    _dashed(canvas, path, paint);
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var i = 0.0; i < metric.length; i += 12) {
        canvas.drawPath(
            metric.extractPath(i, (i + 6).clamp(0, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: V3Colors.chip,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
              width: 32,
              height: 32,
              child: Icon(Icons.arrow_back_rounded,
                  size: 18, color: V3Colors.light)),
        ),
      );
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });
  final String label, title, subtitle, cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      Stack(clipBehavior: Clip.none, children: [
        for (final (left, top, right, color, angle) in [
          (10.0, 10.0, -7.0, V3Colors.edgeWarm2, .055),
          (4.0, 4.0, -3.0, V3Colors.edgeWarm1, -.026),
        ])
          Positioned(
              left: left,
              top: top,
              right: right,
              height: 164,
              child: Transform.rotate(
                  angle: angle,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(16))))),
        Material(
          color: V3Colors.paper2,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 15, 17, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const DecoratedBox(
                          decoration: BoxDecoration(
                              color: V3Colors.terra, shape: BoxShape.circle),
                          child: SizedBox(width: 8, height: 8)),
                      const SizedBox(width: 8),
                      Text(label,
                          style: AppTextStyles.mono(11.5, FontWeight.w700,
                              letterSpacing: 1, color: V3Colors.terraInk)),
                    ]),
                    const SizedBox(height: 7),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.serif(29, FontWeight.w400,
                            color: V3Colors.ink)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.fig(14, FontWeight.w400,
                            color: V3Colors.ink60)),
                    const SizedBox(height: 13),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: V3Colors.terra,
                          borderRadius: BorderRadius.circular(11)),
                      child: Text(cta,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.fig(15, FontWeight.w700,
                              color: V3Colors.paper)),
                    ),
                  ]),
            ),
          ),
        ),
      ]);
}

class _TrailCard extends StatelessWidget {
  const _TrailCard({
    super.key,
    required this.label,
    required this.title,
    this.active = false,
    this.done = false,
    this.onTap,
  });
  final String label, title;
  final bool active, done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: done ? -.05 : .035,
        child: Material(
          color: active ? V3Colors.chip2 : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: active ? V3Colors.amber : V3Colors.light60,
                    width: active ? 1.3 : 1),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: AppTextStyles.mono(10.5, FontWeight.w400,
                            letterSpacing: .7,
                            color: done ? V3Colors.light60 : V3Colors.light70)),
                    const SizedBox(height: 3),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.serif(18, FontWeight.w400,
                            color: V3Colors.light)),
                  ]),
            ),
          ),
        ),
      );
}

class _TrailProgress extends StatelessWidget {
  const _TrailProgress({required this.completed});
  final int completed;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: V3Colors.block, borderRadius: BorderRadius.circular(13)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completed / 4,
                    minHeight: 6,
                    backgroundColor: V3Colors.chip,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(V3Colors.amber),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Text('$completed / 4',
                  style: AppTextStyles.mono(11.5, FontWeight.w400,
                      color: V3Colors.amber)),
            ]),
            const SizedBox(height: 8),
            Text('Une carte suffit pour aujourd’hui. Les autres t’attendront.',
                style: AppTextStyles.fig(13.5, FontWeight.w400,
                    color: V3Colors.light70)),
          ]),
        ),
      );
}

class _ModeSheet extends StatelessWidget {
  const _ModeSheet({required this.onSelected});
  final ValueChanged<QuizMode> onSelected;
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 13, 20, 22),
            decoration: BoxDecoration(
                color: V3Colors.paper2,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x9914170D),
                      blurRadius: 44,
                      offset: Offset(0, -12))
                ]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: const Color(0xFFD3CBB6),
                      borderRadius: BorderRadius.circular(2))),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Comment veux-tu réviser\u202f?',
                    style: AppTextStyles.serif(28, FontWeight.w400,
                        color: V3Colors.ink)),
              ),
              const SizedBox(height: 14),
              for (final (mode, icon, label) in [
                (QuizMode.voice, Icons.mic_rounded, 'Répondre à voix haute'),
                (QuizMode.handsFree, Icons.headset_mic_rounded, 'Mains libres'),
                (QuizMode.typing, Icons.keyboard_rounded, 'Écrire la réponse'),
                (QuizMode.flashcard, Icons.style_rounded, 'Cartes à retourner'),
              ]) ...[
                _ModeChoice(
                    mode: mode,
                    icon: icon,
                    label: label,
                    onTap: () => onSelected(mode)),
                const SizedBox(height: 7),
              ],
            ]),
          ),
        ),
      );
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.mode,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final QuizMode mode;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: V3Colors.paper3,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          key: ValueKey(WidgetKeys.homeReviewMode(mode.name)),
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(icon, size: 19, color: V3Colors.terra),
              const SizedBox(width: 11),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.fig(14.5, FontWeight.w600,
                        color: V3Colors.ink)),
              ),
            ]),
          ),
        ),
      );
}
