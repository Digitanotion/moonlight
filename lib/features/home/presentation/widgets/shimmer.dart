import 'dart:math' as math;
import 'package:flutter/material.dart';

class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration period;
  const Shimmer({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1200),
  });
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final width = MediaQuery.of(context).size.width;
        final dx = (width + 200) * _c.value - 100;
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1.0 + (2.0 * _c.value), 0),
              end: Alignment(1.0 + (2.0 * _c.value), 0),
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.35),
                Colors.white.withOpacity(0.12),
              ],
              stops: const [0.25, 0.5, 0.75],
              transform: GradientRotation(math.pi / 20),
            ).createShader(rect.shift(Offset(dx, 0)));
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}
