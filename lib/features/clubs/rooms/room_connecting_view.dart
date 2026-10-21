// lib/features/clubs/rooms/room_connecting_view.dart
//
// What you see while a club room is being created / opened / connected:
// the room's look (audio or video), a living pulse and a plain-words step
// ("Joining…", "Connecting your mic…") — never a bare spinner.

import 'package:flutter/material.dart';

import 'club_room_models.dart';
import 'live_room_badge.dart' show LiveBars;
import 'room_stage.dart' show MoonColors;

class RoomConnectingView extends StatefulWidget {
  final String stage;
  final RoomState? state;
  final VoidCallback? onCancel;

  const RoomConnectingView({
    super.key,
    required this.stage,
    this.state,
    this.onCancel,
  });

  @override
  State<RoomConnectingView> createState() => _RoomConnectingViewState();
}

class _RoomConnectingViewState extends State<RoomConnectingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final video = s != null && !s.isAudio;
    final colors = video
        ? const [MoonColors.danger, MoonColors.ember]
        : const [MoonColors.violet, MoonColors.magenta];
    final title = (s?.title ?? '').trim().isNotEmpty
        ? s!.title!.trim()
        : (s?.clubName ?? 'Club room');

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: MoonColors.background),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70,
                  size: 30,
                ),
              ),
            ),
            const Spacer(),
            // Pulsing rings around the room icon.
            SizedBox(
              width: 200,
              height: 200,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      _Ring(t: (_pulse.value + i / 3) % 1, color: colors.first),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: colors),
                        boxShadow: [
                          BoxShadow(
                            color: colors.first.withValues(alpha: 0.5),
                            blurRadius: 28,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: video
                          ? const Icon(
                              Icons.videocam_rounded,
                              color: Colors.white,
                              size: 42,
                            )
                          : const LiveBars(height: 34),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                widget.stage,
                key: ValueKey(widget.stage),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14.5),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(colors.last),
                ),
              ),
            ),
            const Spacer(flex: 2),
            if (widget.onCancel != null)
              TextButton(
                onPressed: widget.onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double t; // 0..1
  final Color color;
  const _Ring({required this.t, required this.color});

  @override
  Widget build(BuildContext context) {
    final size = 96 + 104 * t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: (1 - t) * 0.55),
          width: 2,
        ),
      ),
    );
  }
}

/// "Starting your audio room…" card shown while the server creates it.
Future<T> showRoomStarting<T>(
  BuildContext context, {
  required bool video,
  required Future<T> Function() task,
}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: MoonColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: video
                        ? const [MoonColors.danger, MoonColors.ember]
                        : const [MoonColors.violet, MoonColors.magenta],
                  ),
                ),
                alignment: Alignment.center,
                child: video
                    ? const Icon(Icons.videocam_rounded, color: Colors.white)
                    : const LiveBars(height: 24),
              ),
              const SizedBox(height: 16),
              Text(
                'Starting your ${video ? 'video' : 'audio'} room…',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Members will get a notification to join you',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.white12,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    if (nav.canPop()) nav.pop();
  }
}
