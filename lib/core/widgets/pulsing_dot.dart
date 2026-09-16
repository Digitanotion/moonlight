// lib/core/widgets/pulsing_dot.dart
//
// Small dot that continuously grows and glows in place — the shared
// "something is happening in the background" cue, first built for the
// Watch/Discover tab re-tap-to-refresh indicator (home_top_tabs.dart) and
// reused anywhere else that wants the same elegant pulse instead of a
// plain spinner (e.g. a grid's "loading more" tile).

import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class PulsingDot extends StatefulWidget {
  const PulsingDot({
    super.key,
    this.color = AppColors.secondary,
    this.size = 4,
  });

  final Color color;
  final double size;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final scale = 0.75 + t * 1.0; // grows and shrinks
        final glow = 3.0 + t * 9.0; // glows in step with the growth
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.85),
                  blurRadius: glow,
                  spreadRadius: glow * 0.25,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
