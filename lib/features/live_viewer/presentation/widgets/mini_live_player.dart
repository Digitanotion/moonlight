import 'dart:async';

import 'package:flutter/material.dart';

import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';
import 'package:moonlight/core/services/mini_player_controller.dart';
import 'package:moonlight/core/services/pip_service.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/live_viewer_pager.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/pool_video_view.dart';
import 'package:moonlight/main.dart' show MyApp;

/// Mounted once near the app root (main.dart). Shows the draggable in-app
/// mini livestream whenever [MiniPlayerController] is active, and re-opens the
/// full viewer when the user taps it.
class MiniPlayerHost extends StatefulWidget {
  final Widget child;
  const MiniPlayerHost({super.key, required this.child});

  @override
  State<MiniPlayerHost> createState() => _MiniPlayerHostState();
}

class _MiniPlayerHostState extends State<MiniPlayerHost> {
  final _ctrl = MiniPlayerController.instance;
  StreamSubscription<MiniStreamRef>? _expandSub;

  @override
  void initState() {
    super.initState();
    _expandSub = _ctrl.onExpand.listen((ref) {
      MyApp.navigatorKey.currentState?.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => LiveViewerPager(
            items: ref.items,
            initialIndex: ref.index,
            resumingFromMini: true,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _expandSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ctrl, PipService.instance.isInPipMode]),
      child: widget.child, // kept stable — not rebuilt when the mini toggles
      builder: (context, child) => Stack(
        children: [
          child!,
          if (_ctrl.isActive) const _DraggableMini(),
        ],
      ),
    );
  }
}

class _DraggableMini extends StatefulWidget {
  const _DraggableMini();

  @override
  State<_DraggableMini> createState() => _DraggableMiniState();
}

class _DraggableMiniState extends State<_DraggableMini> {
  static const _w = 116.0;
  static const _h = 196.0;
  static const _margin = 12.0;

  Offset? _pos; // top-left; null = default bottom-right

  @override
  Widget build(BuildContext context) {
    // If the OS pushed us into a Picture-in-Picture window (user backgrounded
    // the app while the mini player was up), fill it with just the video.
    if (PipService.instance.isInPipMode.value) {
      return Positioned.fill(
        child: Container(
          color: Colors.black,
          child: PoolVideoView(pool: sl<AgoraEnginePool>()),
        ),
      );
    }

    final media = MediaQuery.of(context);
    final size = media.size;
    final safe = media.padding;

    final maxX = size.width - _w - _margin;
    final maxY = size.height - _h - _margin - safe.bottom;
    final minY = safe.top + _margin;

    final pos = _pos ??
        Offset(maxX, maxY - 64); // sit above the bottom nav by default

    final clamped = Offset(
      pos.dx.clamp(_margin, maxX < _margin ? _margin : maxX),
      pos.dy.clamp(minY, maxY < minY ? minY : maxY),
    );

    return Positioned(
      left: clamped.dx,
      top: clamped.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() {
          _pos = (_pos ?? clamped) + d.delta;
        }),
        onTap: MiniPlayerController.instance.requestExpand,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          color: Colors.black,
          child: SizedBox(
            width: _w,
            height: _h,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PoolVideoView(pool: sl<AgoraEnginePool>()),
                // subtle top scrim so the close button reads
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                    iconSize: 16,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: MiniPlayerController.instance.close,
                  ),
                ),
                const Positioned(
                  left: 6,
                  bottom: 6,
                  child: _LiveDot(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.redAccent, size: 7),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
