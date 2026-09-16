// lib/core/widgets/update_progress_ring.dart
//
// The two pieces of UI that make AutoUpdateService's download visible:
// a thick progress ring that wraps around any child (used around the home
// logo) and fills in real time as the update downloads, and a small
// dismissible banner announcing what's happening. Both are pure
// ValueListenableBuilders over AutoUpdateService's state — no polling.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:moonlight/core/services/auto_update_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';

/// Wraps [child] with a circular progress border that fills clockwise from
/// the top as the background update downloads — half downloaded wraps half
/// the circle, exactly like a story ring. Invisible (adds no padding) when
/// there's nothing to show.
class UpdateProgressRing extends StatelessWidget {
  const UpdateProgressRing({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AutoUpdateStage>(
      valueListenable: AutoUpdateService.instance.stage,
      builder: (context, stage, _) {
        if (stage == AutoUpdateStage.idle) return child;
        return ValueListenableBuilder<double?>(
          valueListenable: AutoUpdateService.instance.progress,
          builder: (context, progress, _) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress ?? 0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder: (context, animated, _) {
                return CustomPaint(
                  painter: _RingPainter(
                    // Only draw once Play has reported a real fraction —
                    // otherwise there's nothing honest to show yet.
                    progress: progress == null ? null : animated,
                    color: stage == AutoUpdateStage.failed
                        ? AppColors.textRed
                        : AppColors.secondary,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: child,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});
  final double? progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == null) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;

    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius, bg);

    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final sweep = 2 * math.pi * progress!.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Elegant, translucent heads-up banner for the update flow. Dismissible
/// while downloading (the ring keeps going regardless — dismissing this
/// only hides the text, it doesn't pause anything); switches to a
/// non-dismissible "restarting shortly" notice once the download finishes,
/// since the user genuinely needs the warning before the app relaunches.
class UpdateStatusBanner extends StatefulWidget {
  const UpdateStatusBanner({super.key});

  @override
  State<UpdateStatusBanner> createState() => _UpdateStatusBannerState();
}

class _UpdateStatusBannerState extends State<UpdateStatusBanner> {
  AutoUpdateStage? _dismissedFor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AutoUpdateStage>(
      valueListenable: AutoUpdateService.instance.stage,
      builder: (context, stage, _) {
        if (stage == AutoUpdateStage.idle || stage == AutoUpdateStage.failed) {
          return const SizedBox.shrink();
        }
        if (_dismissedFor == stage) return const SizedBox.shrink();

        final finishing =
            stage == AutoUpdateStage.downloaded ||
            stage == AutoUpdateStage.restarting;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.32),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      finishing
                          ? Icons.check_circle_rounded
                          : Icons.download_rounded,
                      color: AppColors.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        finishing
                            ? 'Update ready — Moonlight will restart in a moment.'
                            : 'Downloading the latest update in the background…',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!finishing)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _dismissedFor = stage),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
