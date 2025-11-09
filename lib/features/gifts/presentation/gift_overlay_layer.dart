// lib/features/gifts/presentation/gift_overlay_layer.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';

class GiftOverlayLayer extends StatefulWidget {
  const GiftOverlayLayer({super.key});

  @override
  State<GiftOverlayLayer> createState() => _GiftOverlayLayerState();
}

class _GiftOverlayLayerState extends State<GiftOverlayLayer>
    with SingleTickerProviderStateMixin {
  AnimationController? _ac;
  GiftBroadcast? _current;

  @override
  void dispose() {
    _ac?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ViewerBloc, ViewerState>(
      // We only *listen* to state to kick off animations;
      // the widget redraws via setState() from the controller.
      listenWhen: (p, n) => p.giftOverlayQueue != n.giftOverlayQueue,
      listener: (ctx, s) {
        debugPrint(
          '🔁 listener: current=$_current, queue=${s.giftOverlayQueue.length}',
        );
        // If nothing playing and queue non-empty -> start first.
        if (_current == null && s.giftOverlayQueue.isNotEmpty) {
          final next = s.giftOverlayQueue.first;
          debugPrint(
            '▶️ starting queued gift from listener: ${next.giftCode} (queue=${s.giftOverlayQueue.length})',
          );
          _playNext(next);
        }
      },

      buildWhen: (p, n) => false, // don't rebuild from bloc state
      builder: (_, __) => _renderOverlay(), // render from local state
    );
  }

  // --- render current overlay frame ---
  Widget _renderOverlay() {
    if (_current == null || _ac == null) return const SizedBox.shrink();
    final t = _ac!.value;
    final tier = _pickTier(_current!.coinsSpent);

    // Simple, tasteful animations per tier (pop, glow, comet, flare)
    Widget child = FutureBuilder<Widget>(
      future: GiftVisuals.build(
        _current!.giftCode,
        size: _iconSizeForTier(tier),
        title: _current!.giftCode,
      ),
      builder: (_, snap) => Transform.scale(
        scale: _scaleForTier(tier, t),
        child: Opacity(
          opacity: _opacityForTier(tier, t),
          child: Container(
            decoration: _glowForTier(tier, t),
            padding: const EdgeInsets.all(6),
            child:
                snap.data ??
                const Icon(Icons.card_giftcard, size: 64, color: Colors.white),
          ),
        ),
      ),
    );

    // Combo badge
    if ((_current!.comboIndex ?? 1) > 1) {
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: -8,
            top: -8,
            child: _comboBadge(_current!.comboIndex!),
          ),
        ],
      );
    }

    return IgnorePointer(
      child: Positioned.fill(
        child: CustomPaint(
          painter: _TrailPainter(tier: tier, t: t),
          child: _positionForTier(tier, t, child),
        ),
      ),
    );
  }

  void _playNext(GiftBroadcast b) async {
    // If something is currently playing, don't start another (guard).
    if (_current != null) {
      debugPrint(
        '⚠️ _playNext called but already playing: ${_current!.giftCode}',
      );
      return;
    }

    debugPrint('▶️ playNext: ${b.giftCode} coins=${b.coinsSpent}');
    setState(() => _current = b);

    final tier = _pickTier(b.coinsSpent);
    final dur = _tierDuration(tier);

    // dispose any existing controller safely
    try {
      _ac?.stop();
      _ac?.dispose();
    } catch (_) {}
    _ac = AnimationController(vsync: this, duration: dur);

    // Log status changes to be sure completion fires
    _ac!.addStatusListener((st) {
      debugPrint('🔁 AnimationStatus for ${b.giftCode}: $st');
      if (st == AnimationStatus.completed) {
        debugPrint(
          '⏹ animation completed for ${b.giftCode} — dispatching dequeue',
        );
        // Tell bloc to remove the completed item
        context.read<ViewerBloc>().add(const GiftOverlayDequeued());

        // Hide local overlay now
        setState(() => _current = null);

        // Dispose controller safely
        try {
          _ac?.dispose();
        } catch (_) {}
        _ac = null;
      }
    });

    // Repaint via setState when animating
    _ac!.addListener(() => setState(() {}));
    _ac!.forward();
  }

  int _pickTier(int coins) {
    if (coins <= 100) return 1;
    if (coins <= 1000) return 2;
    if (coins <= 5000) return 3;
    return 4;
  }

  Duration _tierDuration(int tier) {
    switch (tier) {
      case 1:
        return const Duration(milliseconds: 700);
      case 2:
        return const Duration(milliseconds: 900);
      case 3:
        return const Duration(milliseconds: 1100);
      default:
        return const Duration(milliseconds: 1200);
    }
  }

  Widget _positionForTier(int tier, double t, Widget child) {
    switch (tier) {
      case 1: // pop center-left
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 18),
            child: child,
          ),
        );
      case 2: // slide from left to center
        final dx = _lerpDouble(-0.9, 0.0, Curves.easeOut.transform(t))!;
        return Align(alignment: Alignment(dx, 0.1), child: child);
      case 3: // diagonal fly (bottom-left to top-right)
        final x = _lerpDouble(-0.9, 0.6, Curves.easeOutCubic.transform(t))!;
        final y = _lerpDouble(0.8, -0.4, Curves.easeOutCubic.transform(t))!;
        return Align(alignment: Alignment(x, y), child: child);
      default: // big center with subtle flare
        return Align(alignment: Alignment.center, child: child);
    }
  }

  double _iconSizeForTier(int tier) {
    switch (tier) {
      case 1:
        return 64;
      case 2:
        return 76;
      case 3:
        return 88;
      default:
        return 100;
    }
  }

  double _scaleForTier(int tier, double t) {
    switch (tier) {
      case 1:
        return 0.8 + 0.2 * Curves.elasticOut.transform(t);
      case 2:
        return 0.9 + 0.1 * Curves.easeOut.transform(t);
      case 3:
        return 1.0;
      default:
        return 0.95 + 0.05 * Curves.easeInOut.transform(t);
    }
  }

  double _opacityForTier(int tier, double t) {
    switch (tier) {
      case 1:
        return Curves.easeInOut.transform(t);
      case 2:
        return Curves.easeIn.transform(min(1, t * 1.2));
      case 3:
        return min(1, t * 1.1);
      default:
        return t < 0.85 ? 1 : (1 - (t - 0.85) * 6); // quick fade at end
    }
  }

  BoxDecoration? _glowForTier(int tier, double t) {
    if (tier == 1) return null;
    final blur =
        (tier == 2
            ? 12.0
            : tier == 3
            ? 16.0
            : 20.0) *
        (0.6 + 0.4 * t);
    return BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Colors.orangeAccent.withOpacity(0.5),
          blurRadius: blur,
          spreadRadius: 1,
        ),
      ],
    );
  }

  Widget _comboBadge(int n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.pinkAccent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '×$n',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  double? _lerpDouble(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}

class _TrailPainter extends CustomPainter {
  final int tier;
  final double t;
  _TrailPainter({required this.tier, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (tier < 3) return;
    final paint = Paint()
      ..color = Colors.orangeAccent.withOpacity(
        0.18 * (tier == 3 ? t : min(1, t * 1.2)),
      )
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // simple diagonal trail
    final start = Offset(
      size.width * (0.1 + 0.4 * t),
      size.height * (0.9 - 0.6 * t),
    );
    final end = Offset(start.dx + 120 * (t), start.dy - 120 * (t));
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.t != t || old.tier != tier;
}
