// lib/features/clubs/rooms/active_room_bar.dart
//
// The slim "You're in a room" bar along the top of the app (like WhatsApp's
// ongoing-call bar). Shown while a club room is running but its screen is
// closed: tap to go back in, mute / unmute, or leave.

import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/main.dart' show MyApp;

import 'active_room.dart';
import 'club_room_controller.dart';
import 'live_room_badge.dart' show LiveBars;
import 'room_stage.dart' show MoonColors;

class ActiveRoomBar extends StatelessWidget {
  final Widget child;
  const ActiveRoomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final room = ActiveRoom.instance;
    return ValueListenableBuilder<ClubRoomController?>(
      valueListenable: room.current,
      builder: (context, c, _) => ValueListenableBuilder<bool>(
        valueListenable: room.screenOpen,
        builder: (context, open, _) => ListenableBuilder(
          listenable: c == null ? room.current : Listenable.merge([c, c.rtc]),
          builder: (context, _) {
            final show = c != null && !open && c.active && c.state != null;
            final mq = MediaQuery.of(context);
            // Same tree whether or not the bar shows, so the app's
            // navigator (and every open screen) is never rebuilt from scratch.
            return Column(
              children: [
                if (show) _Bar(c: c, top: mq.padding.top),
                Expanded(
                  child: MediaQuery(
                    data: show ? mq.removePadding(removeTop: true) : mq,
                    child: child,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final ClubRoomController c;
  final double top;
  const _Bar({required this.c, required this.top});

  void _return() => MyApp.navigatorKey.currentState?.pushNamed(
    RouteNames.clubRoom,
    arguments: {'roomUuid': c.roomUuid},
  );

  Future<void> _leave() async {
    final ctx = MyApp.navigatorKey.currentContext;
    if (ctx == null) return;
    final isHost = c.state?.me.isHost == true;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        backgroundColor: MoonColors.surface,
        title: Text(
          isHost ? 'End the room?' : 'Leave the room?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          isHost
              ? 'You are the host — leaving ends the room for everyone.'
              : 'You can join again while it\'s live.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(
              isHost ? 'End room' : 'Leave',
              style: const TextStyle(color: MoonColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await ActiveRoom.instance.leave();
  }

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final video = !s.isAudio;
    final title = (s.title ?? '').trim().isNotEmpty
        ? s.title!.trim()
        : s.clubName;
    final n = s.participants.length;
    final requests = s.me.canModerate ? s.seatRequests.length : 0;
    final onStage = s.me.onStage;
    final muted = c.rtc.micMuted;

    return Material(
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: video
                ? const [MoonColors.danger, MoonColors.ember]
                : const [MoonColors.violet, MoonColors.magenta],
          ),
        ),
        child: InkWell(
          onTap: _return,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, top + 6, 6, 6),
            child: Row(
              children: [
                const LiveBars(height: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        requests > 0
                            ? '✋ $requests waiting to join · tap to return'
                            : '${video ? 'Video' : 'Audio'} room · $n in · tap to return',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onStage)
                  IconButton(
                    tooltip: muted ? 'Unmute' : 'Mute',
                    visualDensity: VisualDensity.compact,
                    onPressed: c.toggleMic,
                    icon: Icon(
                      muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                IconButton(
                  tooltip: s.me.isHost ? 'End room' : 'Leave',
                  visualDensity: VisualDensity.compact,
                  onPressed: _leave,
                  icon: const Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
