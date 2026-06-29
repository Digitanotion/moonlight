// lib/features/post_view/presentation/widgets/skeleton_line_plus.dart
//
// REWRITE: previous SkeletonLine/SkeletonPill were flat Colors.white12
// boxes with no motion — relying on Skeletonizer's "infer from real
// content" to add shimmer, which silently does nothing when wrapped
// boxes have no decoration/child to bone-ify (this is exactly what was
// happening in feed_skeletons.dart — empty SizedBoxes = nothing to show).
//
// New approach: a single _ShimmerSurface widget drives one continuous
// diagonal gradient sweep, shared via an InheritedWidget-free pattern
// (each shimmering shape listens to the same AnimationController via
// _ShimmerController so every bone on screen pulses in perfect sync —
// this is what makes TikTok/FB/Instagram skeletons feel "premium"
// rather than janky with independently-animating pieces).

import 'package:flutter/material.dart';

// ── Shared animation driver ────────────────────────────────────────────────
// One controller per shimmer "scope" (e.g. one per skeleton screen), reused
// by every bone inside it via ShimmerScope so they all move in lockstep.
class ShimmerScope extends StatefulWidget {
  final Widget child;
  const ShimmerScope({super.key, required this.child});

  @override
  State<ShimmerScope> createState() => _ShimmerScopeState();

  static _ShimmerScopeState of(BuildContext context) {
    final state = context
        .dependOnInheritedWidgetOfExactType<_ShimmerInherited>()
        ?.state;
    assert(state != null, 'ShimmerBone must be used inside a ShimmerScope');
    return state!;
  }
}

class _ShimmerScopeState extends State<ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerInherited(state: this, child: widget.child);
  }
}

class _ShimmerInherited extends InheritedWidget {
  final _ShimmerScopeState state;
  const _ShimmerInherited({required this.state, required super.child});

  @override
  bool updateShouldNotify(_ShimmerInherited oldWidget) => false;
}

// ── Bone — a single shimmering shape ──────────────────────────────────────
// Drop this anywhere inside a ShimmerScope. Renders a base-color rounded
// rect with a diagonal light sweep passing through it continuously.
class ShimmerBone extends StatelessWidget {
  final double? width;
  final double height;
  final double? widthFactor;
  final BorderRadiusGeometry borderRadius;

  const ShimmerBone({
    super.key,
    this.width,
    this.height = 12,
    this.widthFactor,
    this.borderRadius = const BorderRadius.all(Radius.circular(7)),
  });

  static const _base = Color(0xFF171A38);
  static const _sheen = Color(0xFF2A2F5C);

  @override
  Widget build(BuildContext context) {
    final scope = ShimmerScope.of(context);
    final w = width ?? (widthFactor != null
        ? MediaQuery.of(context).size.width * widthFactor!
        : double.infinity);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: w,
        height: height,
        child: AnimatedBuilder(
          animation: scope.controller,
          builder: (context, _) {
            // sweep travels from -1.5 to +1.5 across the box continuously
            final t = scope.controller.value;
            final dx = -1.5 + (3.0 * t);
            return DecoratedBox(
              decoration: BoxDecoration(
                color: _base,
                gradient: LinearGradient(
                  begin: Alignment(dx - 0.4, -0.3),
                  end: Alignment(dx + 0.4, 0.3),
                  colors: const [_base, _sheen, _base],
                  stops: const [0.35, 0.5, 0.65],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Convenience wrappers matching the old API so call-sites don't churn ──

/// Drop-in replacement for the old SkeletonLine — same constructor shape.
class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;
  final double? widthFactor;
  const SkeletonLine({
    super.key,
    this.width,
    this.height = 10,
    this.widthFactor,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerBone(
      width: width,
      height: height,
      widthFactor: widthFactor,
      borderRadius: BorderRadius.circular(6),
    );
  }
}

/// Drop-in replacement for the old SkeletonPill — same constructor shape.
class SkeletonPill extends StatelessWidget {
  final double width;
  final double height;
  const SkeletonPill({super.key, required this.width, this.height = 20});

  @override
  Widget build(BuildContext context) {
    return ShimmerBone(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(24),
    );
  }
}

/// Circle variant for avatars.
class ShimmerCircle extends StatelessWidget {
  final double radius;
  const ShimmerCircle({super.key, required this.radius});

  @override
  Widget build(BuildContext context) {
    return ShimmerBone(
      width: radius * 2,
      height: radius * 2,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}

/// Rectangle variant for media blocks — no fixed corner radius assumption.
class ShimmerBlock extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry borderRadius;
  const ShimmerBlock({
    super.key,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    final scope = ShimmerScope.of(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: AnimatedBuilder(
          animation: scope.controller,
          builder: (context, _) {
            final t = scope.controller.value;
            final dx = -1.5 + (3.0 * t);
            return DecoratedBox(
              decoration: BoxDecoration(
                color: ShimmerBone._base,
                gradient: LinearGradient(
                  begin: Alignment(dx - 0.4, -0.3),
                  end: Alignment(dx + 0.4, 0.3),
                  colors: const [
                    ShimmerBone._base,
                    ShimmerBone._sheen,
                    ShimmerBone._base,
                  ],
                  stops: const [0.35, 0.5, 0.65],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}