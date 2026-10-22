// lib/features/clubs/rooms/live_room_badge.dart
//
// "This club is live" indicators, shared by the club list and club chat.
// Audio rooms: violet pill with moving sound bars. Video rooms: red/ember
// pill with a pulsing dot and camera.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';

import 'club_room_api.dart';
import 'club_room_models.dart';
import 'room_stage.dart' show MoonColors;

/// The club's live-room line, e.g. "Okwy is live now in this club's audio
/// room. Join them". Used on the club page and in club chat (and the push
/// matches it).
String liveRoomHeadline(String host, {required bool isVideo}) =>
    '$host is live now in this club\'s ${isVideo ? 'video' : 'audio'} room. '
    'Join them';

/// Second line under the headline: "5 listening · Title" (may be empty).
String liveRoomDetails(int n, String title, {required bool isVideo}) => [
  if (n > 0) '$n ${isVideo ? 'watching' : 'listening'}',
  if (title.isNotEmpty) title,
].join(' · ');

const _audioGradient = LinearGradient(
  colors: [MoonColors.violet, MoonColors.magenta],
);
const _videoGradient = LinearGradient(
  colors: [MoonColors.danger, MoonColors.ember],
);

/// Small pill: "Audio live · 5" / "Video live · 5".
class LiveRoomBadge extends StatelessWidget {
  final bool isVideo;
  final int count;
  const LiveRoomBadge({super.key, required this.isVideo, this.count = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        gradient: isVideo ? _videoGradient : _audioGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isVideo ? MoonColors.danger : MoonColors.violet).withValues(
              alpha: 0.45,
            ),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isVideo
              ? const _PulseDot()
              : const LiveBars(height: 11, color: Colors.white),
          const SizedBox(width: 5),
          if (isVideo) ...[
            const Icon(Icons.videocam_rounded, color: Colors.white, size: 13),
            const SizedBox(width: 3),
          ],
          Text(
            '${isVideo ? 'Video' : 'Audio'} live${count > 0 ? ' · $count' : ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three bouncing bars, like an equalizer.
class LiveBars extends StatefulWidget {
  final double height;
  final Color color;
  const LiveBars({super.key, this.height = 12, this.color = Colors.white});

  @override
  State<LiveBars> createState() => _LiveBarsState();
}

class _LiveBarsState extends State<LiveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    return SizedBox(
      width: h,
      height: h,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: h / 4.5,
                height:
                    h *
                    (0.35 +
                        0.65 *
                            (0.5 +
                                0.5 *
                                    math.sin(
                                      (_c.value + i * 0.33) * 2 * math.pi,
                                    ))),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
    child: Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// Glowing gradient ring drawn around a club's cover while it's live.
class LiveRing extends StatefulWidget {
  final bool isVideo;
  final Widget child;
  final double radius;
  const LiveRing({
    super.key,
    required this.isVideo,
    required this.child,
    this.radius = 14,
  });

  @override
  State<LiveRing> createState() => _LiveRingState();
}

class _LiveRingState extends State<LiveRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.isVideo ? MoonColors.danger : MoonColors.violet;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          gradient: widget.isVideo ? _videoGradient : _audioGradient,
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.25 + 0.35 * _c.value),
              blurRadius: 6 + 8 * _c.value,
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Club chat: "Audio room is live — Join" banner(s). Polls the club's live
/// rooms so it appears / disappears on its own while the chat is open.
class ClubLiveBanner extends StatefulWidget {
  final String clubUuid;
  const ClubLiveBanner({super.key, required this.clubUuid});

  @override
  State<ClubLiveBanner> createState() => _ClubLiveBannerState();
}

class _ClubLiveBannerState extends State<ClubLiveBanner> {
  final _api = ClubRoomApi();
  List<LiveRoomSummary> _rooms = const [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rooms = await _api.liveRooms(widget.clubUuid);
      if (mounted) setState(() => _rooms = rooms);
    } catch (_) {}
  }

  Future<void> _join(LiveRoomSummary r) async {
    await Navigator.of(
      context,
    ).pushNamed(RouteNames.clubRoom, arguments: {'roomUuid': r.uuid});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      alignment: Alignment.topCenter,
      child: _rooms.isEmpty
          ? const SizedBox(width: double.infinity)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in _rooms)
                  _LiveRoomStrip(room: r, onJoin: () => _join(r)),
              ],
            ),
    );
  }
}

class _LiveRoomStrip extends StatelessWidget {
  final LiveRoomSummary room;
  final VoidCallback onJoin;
  const _LiveRoomStrip({required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final video = room.type == RoomType.video;
    final who = room.host.display;
    final n = room.presentCount;
    final title = (room.title ?? '').trim();
    return GestureDetector(
      onTap: onJoin,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        decoration: BoxDecoration(
          color: MoonColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (video ? MoonColors.danger : MoonColors.violet).withValues(
              alpha: 0.6,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: (video ? MoonColors.danger : MoonColors.violet).withValues(
                alpha: 0.25,
              ),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: video ? _videoGradient : _audioGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: video
                  ? const Icon(Icons.videocam_rounded, color: Colors.white)
                  : const LiveBars(height: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    liveRoomHeadline(who, isVideo: video),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      height: 1.25,
                    ),
                  ),
                  if (liveRoomDetails(n, title, isVideo: video)
                      case final details when details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: video ? _videoGradient : _audioGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Join',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
