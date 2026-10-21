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
import 'package:moonlight/core/services/live_audio_meter.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/clubs/rooms/room_stage.dart' show SoundWave;

/// Wave while [uid] talks (moving with their voice), red mic-off when
/// muted — like club rooms. [muted] overrides (for "me", uid 0).
class LiveTalkIndicator extends StatelessWidget {
  final int uid;
  final bool? muted;
  final double size;
  const LiveTalkIndicator({
    super.key,
    required this.uid,
    this.muted,
    this.size = 11,
  });

  @override
  Widget build(BuildContext context) {
    final meter = LiveAudioMeter.instance;
    return ListenableBuilder(
      listenable: meter,
      builder: (_, _) {
        final isMuted = muted ?? meter.isMuted(uid) ?? false;
        if (isMuted) {
          return Icon(
            Icons.mic_off_rounded,
            size: size + 2,
            color: const Color(0xFFFF6B81),
          );
        }
        return SoundWave(
          active: meter.isSpeaking(uid),
          level: meter.levelOf(uid),
          height: size,
          bars: 4,
        );
      },
    );
  }
}

/// Bottom name chip for a tile: [indicator] + name.
class LiveNameChip extends StatelessWidget {
  final String name;
  final Widget indicator;
  const LiveNameChip({super.key, required this.name, required this.indicator});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: Row(
        children: [
          indicator,
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile frame that glows green while [uid] is talking.
class LiveSpeakingBorder extends StatelessWidget {
  final int uid;
  final bool? muted;
  final Widget child;
  final Color idle;
  const LiveSpeakingBorder({
    super.key,
    required this.uid,
    required this.child,
    this.muted,
    this.idle = const Color(0xD9FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final meter = LiveAudioMeter.instance;
    return ListenableBuilder(
      listenable: meter,
      builder: (_, child) {
        final isMuted = muted ?? meter.isMuted(uid) ?? false;
        final talking = meter.isSpeaking(uid) && !isMuted;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: talking ? const Color(0xFF39D98A) : idle,
              width: talking ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: talking
                    ? const Color(0xFF39D98A).withValues(alpha: 0.55)
                    : Colors.black54,
                blurRadius: talking ? 14 : 12,
              ),
            ],
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}

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
      child: SizedBox(
        width: width,
        height: height,
        child: LiveSpeakingBorder(
          uid: guest.uid,
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
                  child: LiveNameChip(
                    name: guest.name,
                    indicator: LiveTalkIndicator(uid: guest.uid),
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

/// Zoom-style stage: the main video (host for viewers, your own camera for
/// the host) fills the screen with guests in a column on the right. Tap a
/// guest → they fill the screen and the main video shrinks into the
/// column; tap the small main tile (or the same guest) → back to normal.
///
/// The main video widget is never rebuilt or re-parented — it only
/// animates between full screen and the tile — so the camera / stream
/// keeps running without a black flash.
class LiveSpotlightStage extends StatefulWidget {
  final Widget main;
  final String mainLabel;

  /// Agora uid of the main video (0 = me), for its wave / mute icon.
  final int? mainUid;
  final bool? mainMuted;
  final LiveGuestsController guests;
  final Widget Function(LiveGuest g) videoFor;
  final String? hideUuid;
  final double top;

  /// Long-press on a guest (e.g. host actions: remove from box).
  final void Function(LiveGuest g)? onLongPressGuest;

  /// False hides the guests (PiP window, paywall) while keeping the main
  /// video mounted.
  final bool showGuests;

  /// A fixed tile at the top of the column (a guest's own camera, "You").
  /// Given the tile size so it matches the guest tiles.
  final Widget Function(double width, double height)? leadingTile;

  const LiveSpotlightStage({
    this.showGuests = true,
    this.leadingTile,
    super.key,
    required this.main,
    required this.mainLabel,
    this.mainUid,
    this.mainMuted,
    required this.guests,
    required this.videoFor,
    this.hideUuid,
    this.top = 110,
    this.onLongPressGuest,
  });

  @override
  State<LiveSpotlightStage> createState() => _LiveSpotlightStageState();
}

class _LiveSpotlightStageState extends State<LiveSpotlightStage> {
  String? _spotUuid;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.guests,
      builder: (context, _) {
        final all = widget.showGuests
            ? widget.guests.guests
                  .where((g) => g.uuid != widget.hideUuid)
                  .toList()
            : const <LiveGuest>[];
        // Spotlighted guest left the box → back to normal.
        LiveGuest? spot;
        for (final g in all) {
          if (g.uuid == _spotUuid) spot = g;
        }
        if (spot == null && _spotUuid != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _spotUuid = null);
          });
        }

        return LayoutBuilder(
          builder: (context, box) => _stage(context, all, spot, box.biggest),
        );
      },
    );
  }

  Widget _stage(
    BuildContext context,
    List<LiveGuest> all,
    LiveGuest? spot,
    Size size,
  ) {
    final w = (size.width * 0.26).clamp(86.0, 128.0);
    final h = w * 4 / 3;
    final mainRect = spot == null
        ? Rect.fromLTWH(0, 0, size.width, size.height)
        : Rect.fromLTWH(size.width - w - 8, widget.top, w, h);

    return Stack(
      fit: StackFit.expand,
      children: [
        // The spotlighted guest, full screen.
        if (spot != null)
          Positioned.fill(
            key: ValueKey('spot_${spot.uid}'),
            child: GestureDetector(
              onTap: () => setState(() => _spotUuid = null),
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.videoFor(spot),
                    Positioned(
                      left: 12,
                      bottom: 150,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LiveTalkIndicator(uid: spot.uid, size: 13),
                            const SizedBox(width: 6),
                            Text(
                              spot.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Main video: same widget always, only its frame animates.
        AnimatedPositioned(
          key: const ValueKey('main_video'),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          left: mainRect.left,
          top: mainRect.top,
          width: mainRect.width,
          height: mainRect.height,
          child: GestureDetector(
            onTap: spot == null ? null : () => setState(() => _spotUuid = null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(spot == null ? 0 : 14),
                border: spot == null
                    ? null
                    : Border.all(color: Colors.white.withValues(alpha: 0.85)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.main,
                  if (spot != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LiveNameChip(
                        name: widget.mainLabel,
                        indicator: widget.mainUid == null
                            ? const SizedBox.shrink()
                            : LiveTalkIndicator(
                                uid: widget.mainUid!,
                                muted: widget.mainMuted,
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // The rest of the box (minus the spotlighted guest), shifted
        // below the shrunken main tile while spotlighting.
        if (widget.leadingTile != null ||
            all.where((g) => g.uuid != spot?.uuid).isNotEmpty)
          Positioned(
            top: spot == null ? widget.top : widget.top + h + 8,
            right: 8,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: size.height * 0.5),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    if (widget.leadingTile != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: w,
                          height: h,
                          child: widget.leadingTile!(w, h),
                        ),
                      ),
                    for (final g in all.where((g) => g.uuid != spot?.uuid))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onLongPress: widget.onLongPressGuest == null
                              ? null
                              : () => widget.onLongPressGuest!(g),
                          child: _GuestTile(
                            key: ValueKey('guest_${g.uid}'),
                            guest: g,
                            width: w,
                            height: h,
                            video: widget.videoFor(g),
                            onTap: () => setState(() => _spotUuid = g.uuid),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
