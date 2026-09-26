// lib/core/widgets/app_logo_loader.dart
//
// The app-wide loading indicator — replaces CircularProgressIndicator
// everywhere except the Home re-tap-to-refresh cue (see pulsing_dot.dart,
// which stays as-is). A small circular crop of the app logo that zooms
// in/out, wobbles ("dances"), and glows alternating orange/blue — funky but
// small enough not to distract at spinner sizes.
//
// Drop-in usage: swap `CircularProgressIndicator()` for `AppLogoLoader()`.
// Sizes itself to the tightest bound of its parent's constraints (same as
// CircularProgressIndicator), or to [size] when given explicitly.

import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class AppLogoLoader extends StatefulWidget {
  const AppLogoLoader({super.key, this.size});

  /// Explicit diameter. If null, fills the tightest finite constraint from
  /// the parent (falling back to 36 when unconstrained).
  final double? size;

  @override
  State<AppLogoLoader> createState() => _AppLogoLoaderState();
}

// Keyframes at t = 0, 0.25, 0.5, 0.75, 1.0 — mirrors the CSS sample
// (scale/rotation "dance", degrees) shown to and approved by the user.
const List<double> _kScaleKeys = [0.82, 1.08, 0.90, 1.14, 0.82];
const List<double> _kRotateDegKeys = [-6, 3, -3, 5, -6];

double _keyframe(List<double> keys, double t) {
  final segment = t * (keys.length - 1);
  final i = segment.floor().clamp(0, keys.length - 2);
  final localT = segment - i;
  return keys[i] + (keys[i + 1] - keys[i]) * localT;
}

class _AppLogoLoaderState extends State<AppLogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double diameter =
            widget.size ??
            (constraints.hasBoundedWidth && constraints.hasBoundedHeight
                ? constraints.biggest.shortestSide
                : 36);

        return SizedBox(
          width: diameter,
          height: diameter,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value;
              final scale = _keyframe(_kScaleKeys, t);
              final rotation =
                  _keyframe(_kRotateDegKeys, t) * (3.141592653589793 / 180);

              // Glow ping-pongs between orange and logo-blue twice per loop.
              final glowT = 1 - (t * 2 % 2 - 1).abs();
              final glowColor = Color.lerp(
                AppColors.secondary,
                const Color(0xFF3D5CFF),
                glowT,
              )!;

              return Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: const DecorationImage(
                        image: AssetImage('assets/images/logo.png'),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.75),
                          blurRadius: diameter * 0.35,
                          spreadRadius: diameter * 0.06,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
