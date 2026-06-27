import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// Injected by test env files via --dart-define-from-file. False in production.
const _kTestMode = bool.fromEnvironment('TEST_MODE');

/// The VocabKR signature waveform — symmetric bars that animate in a staggered
/// sine wave, teal (FR) on the outside fading to clay (KR) at the centre.
///
/// Reuse it for:
///  - Study screen watermark (large, 0.4 opacity, behind the prompt word)
///  - Audio preview rows (small, fully opaque)
///  - Listening indicator (animating while STT is active)
///  - Session summary celebration chord
///  - Empty-state decoration
class VkWaveform extends StatefulWidget {
  const VkWaveform({
    super.key,
    this.height = 80,
    this.barWidth = 7,
    this.gap = 5,
    this.isAnimating = true,
    this.opacity = 1.0,
    this.flatAtRest = false,
    this.duration = const Duration(milliseconds: 1200),
    this.amplitude = 1.0,
    this.glow = false,
  });

  /// Total height of the waveform container.
  final double height;

  /// Width of each bar in logical pixels.
  final double barWidth;

  /// Gap between bars.
  final double gap;

  /// Whether the bars are currently animating. Set false to freeze at rest
  /// (respects prefers-reduced-motion — [build] checks it automatically).
  final bool isAnimating;

  /// Overall opacity — set to 0.4 for the study-screen watermark.
  final double opacity;

  /// When true and [isAnimating] is false, the bars rest as a flat, even line
  /// of short bars (a dormant equaliser) instead of the static "mountain"
  /// shape. Used by the quiz watermark so it reads as still until the mic is
  /// listening, then ripples to life.
  ///
  /// When false and [isAnimating] is false, the bars freeze in the static
  /// mountain profile ("frozen mountain" — used while the prompt audio reads).
  final bool flatAtRest;

  /// Animation period for one full ripple. Lower = faster (e.g. ~700 ms while
  /// listening, ~1200 ms at rest, slower while analysing).
  final Duration duration;

  /// Scales how far the bars swing from the baseline (1.0 = full ripple, lower =
  /// a calmer, low-amplitude wobble — e.g. the analysing / "pas entendu" states).
  final double amplitude;

  /// Adds a soft coloured glow around each bar — the brighter "your turn"
  /// listening state.
  final bool glow;

  @override
  State<VkWaveform> createState() => _VkWaveformState();
}

class _VkWaveformState extends State<VkWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 9 bars: symmetric mountain shape (normalised 0–1 heights).
  static const _heights = [0.28, 0.48, 0.72, 0.88, 1.0, 0.88, 0.72, 0.48, 0.28];

  // Phase offsets in turns (0–1) — edges lead, centre follows.
  static const _phases = [0.0, 0.08, 0.17, 0.25, 0.33, 0.25, 0.17, 0.08, 0.0];

  // Colour palette: tealLight → teal → teal → clayLight → clay (mirror).
  static const _colors = [
    AppColors.tealLight,
    AppColors.teal,
    AppColors.teal,
    AppColors.clayLight,
    AppColors.clay,
    AppColors.clayLight,
    AppColors.teal,
    AppColors.teal,
    AppColors.tealLight,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.isAnimating && !_kTestMode) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(VkWaveform old) {
    super.didUpdateWidget(old);
    if (widget.duration != old.duration) {
      _ctrl.duration = widget.duration;
      if (_ctrl.isAnimating) _ctrl.repeat(); // restart at the new speed
    }
    final shouldAnimate = widget.isAnimating &&
        !MediaQuery.of(context).disableAnimations &&
        !_kTestMode;
    if (shouldAnimate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!shouldAnimate && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0.5; // rest at mid-height
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final animating = widget.isAnimating && !reducedMotion && !_kTestMode;
    // Resting flat: bars freeze as an even, short line until animation resumes.
    final restFlat = !animating && widget.flatAtRest;

    return Opacity(
      opacity: widget.opacity,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = animating ? _ctrl.value : 0.5;
          return SizedBox(
            height: widget.height,
            child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_heights.length, (i) {
              // Sine wave: 0.28 at trough, 1.0 at peak.
              final raw =
                  math.sin(2 * math.pi * (t + _phases[i])) * 0.5 + 0.5;
              // [amplitude] scales the dynamic swing only (baseline stays), so a
              // low amplitude reads as a calm wobble rather than a full ripple.
              final scale = 0.28 + raw * 0.72 * widget.amplitude;
              // Flat rest collapses every bar to a uniform short height so the
              // gadget reads as "off"; otherwise follow the mountain profile.
              final barH = restFlat
                  ? widget.barWidth
                  : widget.height * _heights[i] * scale;

              return Padding(
                padding: EdgeInsets.only(
                    left: i == 0 ? 0 : widget.gap / 2,
                    right: i == _heights.length - 1 ? 0 : widget.gap / 2),
                child: Container(
                  width: widget.barWidth,
                  height: barH.clamp(widget.barWidth, widget.height),
                  decoration: BoxDecoration(
                    color: _colors[i],
                    borderRadius:
                        BorderRadius.circular(widget.barWidth / 2),
                    boxShadow: widget.glow
                        ? [
                            BoxShadow(
                              color: _colors[i].withValues(alpha: 0.55),
                              blurRadius: 8,
                              spreadRadius: 0.5,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
          );
        },
      ),
    );
  }
}
