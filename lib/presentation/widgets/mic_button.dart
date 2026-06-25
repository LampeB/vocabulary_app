import 'package:flutter/material.dart';
import '../providers/quiz/quiz_provider.dart';
import '../../../core/theme/app_colors.dart';

const _kTestMode = bool.fromEnvironment('TEST_MODE');

class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.isListening,
    required this.answerState,
    required this.onTap,
  });
  final bool isListening;
  final QuizAnswerState answerState;
  final VoidCallback onTap;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // Keep controller in the standard [0, 1] range.
    // CurvedAnimation passes parent.value directly to the curve — it does NOT
    // normalise by lowerBound/upperBound, so a non-[0,1] controller causes
    // "parametric value outside of [0, 1]" assertion failures at 120 Hz.
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _scale = _pulse
        .drive(CurveTween(curve: Curves.easeInOut))
        .drive(Tween<double>(begin: 1.0, end: 1.25));
  }

  @override
  void didUpdateWidget(MicButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening && !_pulse.isAnimating && !_kTestMode) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isListening) {
      _pulse.stop();
      _pulse.value = 0.0; // 0 → scale 1.0 (rest, no pulse)
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.answerState) {
        QuizAnswerState.correct => AppColors.success,
        QuizAnswerState.incorrect => AppColors.secondary,
        _ => widget.isListening ? AppColors.secondary : AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.answerState == QuizAnswerState.idle ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: widget.isListening
                ? [
                    BoxShadow(
                        color: _color.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 4)
                  ]
                : [],
          ),
          child: Icon(
            widget.isListening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}
