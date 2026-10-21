// lib/features/live_viewer/presentation/widgets/live_guest_strip.dart
//
// The "box": everyone the host has brought on camera, shown as a column of
// live tiles down the right side of the stream (several guests at once).
// Shared by the host screen, viewers and the guests themselves — each
// passes its own way of drawing a remote video.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';

class LiveGuest {
  final String uuid;
  final int uid; // Agora uid (= user id on the API)
  final String name;
  final String? avatar;
  const LiveGuest({
    required this.uuid,
    required this.uid,
    required this.name,
    this.avatar,
  });
}

/// Who's in the box right now. Refreshes on role changes (realtime) and
/// every 8s as a backup.
class LiveGuestsController extends ChangeNotifier {
  LiveGuestsController({
    required this.livestreamParam,
    required this.numericId,
  }) {
    final pusher = sl<PusherService>();
    for (final e in _events) {
      pusher.bind(_meta, e, _onEvent);
    }
    refresh();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => refresh());
  }

  /// Path segment for the API (numeric id or uuid).
  final String livestreamParam;
  final int numericId;

  static const _events = [
    'participant.role_changed',
    'participant.removed',
    'participants.removed',
  ];
  String get _meta => 'live.$numericId.meta';

  List<LiveGuest> guests = const [];
  Timer? _poll;
  bool _disposed = false;

  void _onEvent(Map<String, dynamic> _) => refresh();

  Future<void> refresh() async {
    try {
      final res = await sl<DioClient>().dio.get(
        '/api/v1/live/$livestreamParam/participants',
        queryParameters: {'role': 'guest', 'per_page': 20},
      );
      final list = ((res.data as Map)['data'] as List?) ?? const [];
      final next = <LiveGuest>[];
      for (final raw in list) {
        final m = Map<String, dynamic>.from(raw as Map);
        final uid = (m['rtc_uid'] as num?)?.toInt() ?? 0;
        if (uid == 0) continue;
        next.add(
          LiveGuest(
            uuid: m['user_uuid']?.toString() ?? '',
            uid: uid,
            name: (m['display_name'] ?? m['user_slug'] ?? 'Guest').toString(),
            avatar: m['avatar']?.toString(),
          ),
        );
      }
      if (_disposed) return;
      final changed =
          next.length != guests.length ||
          next.indexed.any((e) => guests[e.$1].uid != e.$2.uid);
      guests = next;
      if (changed) notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    final pusher = sl<PusherService>();
    for (final e in _events) {
      pusher.unbind(_meta, e, _onEvent);
    }
    super.dispose();
  }
}

/// Right-side column of guest tiles.
class LiveGuestStrip extends StatelessWidget {
  final LiveGuestsController controller;

  /// Draws a guest's live video (remote, or the local camera for "me").
  final Widget Function(LiveGuest g) videoFor;

  /// Hide this user (e.g. yourself when your own tile is drawn elsewhere).
  final String? hideUuid;
  final void Function(LiveGuest g)? onTap;
  final double top;

  const LiveGuestStrip({
    super.key,
    required this.controller,
    required this.videoFor,
    this.hideUuid,
    this.onTap,
    this.top = 110,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final guests = controller.guests
            .where((g) => g.uuid != hideUuid)
            .toList();
        if (guests.isEmpty) return const SizedBox.shrink();
        final size = MediaQuery.of(context).size;
        final w = (size.width * 0.26).clamp(86.0, 128.0);
        final h = w * 4 / 3;
        return Positioned(
          top: top,
          right: 8,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: size.height * 0.52),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  for (final g in guests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GuestTile(
                        key: ValueKey('guest_${g.uid}'),
                        guest: g,
                        width: w,
                        height: h,
                        video: videoFor(g),
                        onTap: onTap == null ? null : () => onTap!(g),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GuestTile extends StatelessWidget {
  final LiveGuest guest;
  final double width;
  final double height;
  final Widget video;
  final VoidCallback? onTap;

  const _GuestTile({
    super.key,
    required this.guest,
    required this.width,
    required this.height,
    required this.video,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Avatar underneath until (or if) the camera shows.
              Container(
                color: const Color(0xFF1B1446),
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: width * 0.2,
                  backgroundColor: Colors.white12,
                  backgroundImage: (guest.avatar ?? '').startsWith('http')
                      ? NetworkImage(guest.avatar!)
                      : null,
                  child: (guest.avatar ?? '').startsWith('http')
                      ? null
                      : Text(
                          guest.name.isNotEmpty
                              ? guest.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              video,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 5),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Text(
                    guest.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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
