import 'package:flutter/material.dart';
import '../providers/quiz/quiz_provider.dart';
import '../../../core/theme/app_colors.dart';

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
    _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
        lowerBound: 1.0,
        upperBound: 1.25);
    _scale = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(MicButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isListening) {
      _pulse.stop();
      _pulse.value = 1.0;
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
                        color: _color.withOpacity(0.4),
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
