import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// A readable scroll surface that makes further content explicit.
///
/// The cue disappears after reaching the end, so it never covers an action
/// that is already visible. It is intentionally independent of lesson UI and
/// can be reused by settings or rich list-detail screens later.
class ScrollAffordance extends StatefulWidget {
  const ScrollAffordance({
    required this.child,
    required this.hint,
    super.key,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final String hint;
  final EdgeInsetsGeometry padding;

  @override
  State<ScrollAffordance> createState() => _ScrollAffordanceState();
}

class _ScrollAffordanceState extends State<ScrollAffordance> {
  final _controller = ScrollController();
  var _showCue = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncCue);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCue());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncCue)
      ..dispose();
    super.dispose();
  }

  void _syncCue() {
    if (!_controller.hasClients || !mounted) return;
    final position = _controller.position;
    final show = position.maxScrollExtent > 0 &&
        position.pixels < position.maxScrollExtent - 2;
    if (show != _showCue) setState(() => _showCue = show);
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _controller,
              padding: widget.padding,
              child: widget.child,
            ),
          ),
          Positioned(
            right: 16,
            bottom: 12,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showCue ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1F000000), blurRadius: 10),
                    ],
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.hint,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.muted)),
                        const SizedBox(width: 3),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 17),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}
