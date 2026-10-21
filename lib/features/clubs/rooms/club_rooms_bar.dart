// lib/features/clubs/rooms/club_rooms_bar.dart
//
// Club page panel: live audio / video rooms to join, and buttons to start
// one (audio: owner / admins; video: any member).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/clubs/presentation/club_coins_ui.dart';

import 'club_room_api.dart';
import 'club_room_models.dart';
import 'live_room_badge.dart';
import 'room_connecting_view.dart';
import 'room_stage.dart' show MoonColors;

class ClubRoomsBar extends StatefulWidget {
  final String clubUuid;
  final bool canOpenAudio;

  const ClubRoomsBar({
    super.key,
    required this.clubUuid,
    required this.canOpenAudio,
  });

  @override
  State<ClubRoomsBar> createState() => _ClubRoomsBarState();
}

class _ClubRoomsBarState extends State<ClubRoomsBar> {
  final _api = ClubRoomApi();
  List<LiveRoomSummary> _rooms = const [];
  Timer? _poll;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Rooms come and go; a light poll keeps the panel honest.
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

  Future<void> _openRoom(String uuid) async {
    await Navigator.of(
      context,
    ).pushNamed(RouteNames.clubRoom, arguments: {'roomUuid': uuid});
    _load();
  }

  Future<void> _start(RoomType type) async {
    final setup = await showModalBottomSheet<(int?, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF17142E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StartSheet(type: type),
    );
    if (setup == null) return;
    setState(() => _starting = true);
    try {
      final room = await showRoomStarting(
        context,
        video: type == RoomType.video,
        task: () => _api.start(
          widget.clubUuid,
          type: type,
          capacity: setup.$1,
          title: setup.$2,
        ),
      );
      if (mounted) await _openRoom(room.uuid);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 409 &&
          data is Map &&
          data['room_uuid'] != null) {
        if (mounted) await _openRoom(data['room_uuid'].toString());
      } else if (mounted) {
        await showCoinError(context, e);
      }
    } catch (e) {
      if (mounted) await showCoinError(context, e);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _rooms.any((r) => r.type == RoomType.audio);
    final hasVideo = _rooms.any((r) => r.type == RoomType.video);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in _rooms)
          _LiveRoomCard(room: r, onJoin: () => _openRoom(r.uuid)),
        Row(
          children: [
            if (widget.canOpenAudio && !hasAudio)
              Expanded(
                child: _StartButton(
                  icon: Icons.graphic_eq,
                  label: 'Start audio room',
                  busy: _starting,
                  onTap: () => _start(RoomType.audio),
                ),
              ),
            if (widget.canOpenAudio && !hasAudio && !hasVideo)
              const SizedBox(width: 10),
            if (!hasVideo)
              Expanded(
                child: _StartButton(
                  icon: Icons.videocam,
                  label: 'Start video room',
                  busy: _starting,
                  onTap: () => _start(RoomType.video),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LiveRoomCard extends StatelessWidget {
  final LiveRoomSummary room;
  final VoidCallback onJoin;
  const _LiveRoomCard({required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final video = room.type == RoomType.video;
    final title = (room.title ?? '').trim();
    final n = room.presentCount;
    return GestureDetector(
      onTap: onJoin,
      child: LiveRing(
        isVideo: video,
        radius: 18,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            color: MoonColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
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
                    : const LiveBars(height: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LiveRoomBadge(isVideo: video),
                        if (room.isPremium) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.workspace_premium,
                            color: MoonColors.gold,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      liveRoomHeadline(room.host.display, isVideo: video),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Join them'
                      '${n > 0 ? ' · $n ${video ? 'watching' : 'listening'}' : ''}'
                      '${title.isNotEmpty ? ' · $title' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: video
                        ? const [MoonColors.danger, MoonColors.ember]
                        : const [MoonColors.violet, MoonColors.magenta],
                  ),
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
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  const _StartButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white30),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _StartSheet extends StatefulWidget {
  final RoomType type;
  const _StartSheet({required this.type});

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> {
  final _title = TextEditingController();
  double _capacity = 20;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = widget.type == RoomType.audio;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        18,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            audio ? 'Start an audio room' : 'Start a video room',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            audio
                ? 'Everyone in the room can talk. The first 10 people join free; '
                      'after that each pays 10 coins to you (the club owner).'
                : 'Up to 10 people on camera. Others watch and comment. Men pay '
                      '20 coins to ask for a camera seat; ladies join free. You can '
                      'switch it to premium inside.',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            maxLength: 120,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Topic (optional)',
              hintStyle: const TextStyle(color: Colors.white38),
              counterStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (audio) ...[
            Text(
              'Room size: ${_capacity.round()} people',
              style: const TextStyle(color: Colors.white),
            ),
            Slider(
              value: _capacity,
              min: 2,
              max: 50,
              divisions: 48,
              activeColor: const Color(0xFFFF7A00),
              onChanged: (v) => setState(() => _capacity = v),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).pop((audio ? _capacity.round() : null, _title.text.trim())),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Go live'),
            ),
          ),
        ],
      ),
    );
  }
}
