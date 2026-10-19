// lib/features/clubs/rooms/club_room_screen.dart
//
// Club revamp: one screen for both room types.
//
//  • Audio room — WhatsApp-style group voice call: everyone in it can
//    talk; avatars light up while speaking. Host / owner can remove anyone.
//  • Video room — up to 10 cameras in a grid; everyone else watches,
//    listens and comments. Viewers pay to ask for a seat (free for the
//    host, owner and ladies) and the host / owner approves. Premium hides
//    the premium cameras (audio still plays) until a man pays.
//
// Both have the comment section (write / reply / edit / delete, photos and
// videos) and gifting (the host, one person, or everyone).

import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/core/services/wakelock_coordinator.dart';
import 'package:moonlight/core/widgets/app_logo_loader.dart';
import 'package:moonlight/features/clubs/presentation/club_coins_ui.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart'
    show GiftItem;
import 'package:moonlight/widgets/top_snack.dart';
import 'package:video_player/video_player.dart';

import 'club_room_controller.dart';
import 'club_room_models.dart';
import 'room_stage.dart';

const _panel = Color(0xFF17142E);
const _accent = Color(0xFFFF7A00);
const _gold = Color(0xFFFFC107);

class ClubRoomScreen extends StatefulWidget {
  final String roomUuid;
  const ClubRoomScreen({super.key, required this.roomUuid});

  @override
  State<ClubRoomScreen> createState() => _ClubRoomScreenState();
}

class _ClubRoomScreenState extends State<ClubRoomScreen> {
  late final ClubRoomController c = ClubRoomController(widget.roomUuid);
  bool _opening = true;
  bool _closedDialogShown = false;

  @override
  void initState() {
    super.initState();
    WakelockCoordinator.instance.acquire();
    c.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    WakelockCoordinator.instance.release();
    c.removeListener(_onChange);
    if (c.state?.me.inRoom == true && !c.ended && !c.removed) {
      c.leave();
    }
    c.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if ((c.ended || c.removed) && !_closedDialogShown && !_opening) {
      _closedDialogShown = true;
      _showClosed(
        c.removed ? 'You were removed from this room.' : 'This room has ended.',
      );
    }
  }

  Future<void> _open() async {
    try {
      final s = await c.load();
      if (!s.isLive) {
        _opening = false;
        _showClosed('This room has ended.');
        return;
      }
      if (s.me.removed) {
        _opening = false;
        _showClosed('You were removed from this room.');
        return;
      }
      if (!s.me.inRoom && s.me.joinFeeCoins > 0) {
        if (!mounted) return;
        final ok = await confirmCoinSpend(
          context,
          title: 'Join the audio room',
          coins: s.me.joinFeeCoins,
          detail:
              'The ${s.freeSlots} free places are taken. The entry fee goes '
              'to the club owner.',
          confirmLabel: 'Pay & join',
        );
        if (!ok) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }
      await c.enter();
    } catch (e) {
      if (!mounted) return;
      await showCoinError(context, e);
      if (mounted) Navigator.of(context).pop();
      return;
    } finally {
      _opening = false;
      if (mounted) setState(() {});
    }
  }

  void _showClosed(String msg) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        backgroundColor: _panel,
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(d).pop();
              Navigator.of(context).maybePop();
            },
            child: const Text('OK', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) await showCoinError(context, e);
    }
  }

  // ── host / owner menus ──────────────────────────────────────────────

  Future<void> _confirmLeave() async {
    final s = c.state;
    if (s == null) return;
    final isHost = s.me.isHost;
    final canEnd = s.me.canModerate;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (b) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isHost)
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: const Text(
                  'Leave room',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(b, 'leave'),
              ),
            if (canEnd)
              ListTile(
                leading: const Icon(Icons.stop_circle, color: Colors.redAccent),
                title: const Text(
                  'End room for everyone',
                  style: TextStyle(color: Colors.redAccent),
                ),
                subtitle: isHost
                    ? const Text(
                        'You are the host — leaving ends the room.',
                        style: TextStyle(color: Colors.white54),
                      )
                    : null,
                onTap: () => Navigator.pop(b, 'end'),
              ),
          ],
        ),
      ),
    );
    if (choice == 'leave') {
      await c.leave();
      if (mounted) Navigator.of(context).pop();
    } else if (choice == 'end') {
      _closedDialogShown = true;
      await _run(c.end);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _participantActions(RoomParticipant p) {
    final s = c.state;
    if (s == null || !s.me.canModerate || p.user.isHost) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (b) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: _Avatar(p.user, size: 36),
              title: Text(
                p.user.display,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (!s.isAudio && p.role == 'guest')
              ListTile(
                leading: const Icon(Icons.videocam_off, color: Colors.white),
                title: const Text(
                  'Bring down from camera',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(b);
                  _run(() => c.bringDown(p.user.uuid));
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.redAccent),
              title: const Text(
                'Remove from room',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(b);
                _run(() => c.bringDown(p.user.uuid, kick: true));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openSeatRequests() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AnimatedBuilder(
        animation: c,
        builder: (b, _) {
          final reqs = c.state?.seatRequests ?? const [];
          final s = c.state;
          final seatsLeft = s == null ? 0 : s.capacity - s.onStage.length;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Requests to join camera · $seatsLeft seat${seatsLeft == 1 ? '' : 's'} left',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (reqs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No requests right now.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  for (final u in reqs)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _Avatar(u, size: 38),
                      title: Text(
                        u.display,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Decline',
                            icon: const Icon(
                              Icons.close,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                _run(() => c.decideSeat(u.uuid, false)),
                          ),
                          IconButton(
                            tooltip: 'Approve',
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.greenAccent,
                            ),
                            onPressed: seatsLeft <= 0
                                ? null
                                : () => _run(() => c.decideSeat(u.uuid, true)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPremium() async {
    final s = c.state;
    if (s == null) return;
    final result = await showModalBottomSheet<(bool, int, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PremiumSheet(current: s.premium),
    );
    if (result == null) return;
    await _run(
      () => c.setPremium(result.$1, price: result.$2, mode: result.$3),
    );
  }

  Future<void> _unlockPremium() async {
    final s = c.state;
    if (s == null) return;
    final ok = await confirmCoinSpend(
      context,
      title: 'Unlock premium',
      coins: s.premium.priceCoins,
      detail: 'See every camera in this room. Coins go to the club owner.',
      confirmLabel: 'Unlock',
    );
    if (ok) await _run(c.payPremium);
  }

  Future<void> _requestSeat() async {
    final s = c.state;
    if (s == null) return;
    final ok = await confirmCoinSpend(
      context,
      title: 'Ask to join on camera',
      coins: s.me.seatFeeCoins,
      detail:
          'The host approves requests. If you\'re declined, you get the coins back.',
      confirmLabel: 'Pay & request',
    );
    if (ok) await _run(c.requestSeat);
  }

  void _openGifts() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GiftSheet(controller: c),
    );
  }

  void _openComments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(controller: c),
    );
  }

  // ── build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = c.state;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (c.ended || c.removed || s == null || !s.me.inRoom) {
          Navigator.of(context).pop();
        } else {
          _confirmLeave();
        }
      },
      child: Scaffold(
        backgroundColor: MoonColors.night,
        body: s == null || _opening
            ? const Center(child: AppLogoLoader())
            : AnimatedBuilder(
                animation: c.rtc,
                builder: (context, _) =>
                    s.isAudio ? _audio(context, s) : _video(context, s),
              ),
      ),
    );
  }

  // ── view wiring ─────────────────────────────────────────────────────

  bool _isMe(RoomParticipant p) => p.user.uuid == c.myUuid;

  bool _isSpeaking(RoomParticipant p) {
    final rtc = c.rtc;
    final muted = _isMuted(p);
    return !muted && rtc.speaking[_isMe(p) ? 0 : p.user.uid] == true;
  }

  bool _isMuted(RoomParticipant p) => _isMe(p) ? c.rtc.micMuted : p.micMuted;

  Widget? _videoFor(RoomParticipant p) {
    final rtc = c.rtc;
    final engine = rtc.engine;
    if (engine == null || !rtc.joined) return null;
    if (_isMe(p)) {
      if (rtc.cameraOff) return null;
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: engine,
          // Cover: fill the tile and crop, never letterbox.
          canvas: const VideoCanvas(
            uid: 0,
            renderMode: RenderModeType.renderModeHidden,
          ),
        ),
      );
    }
    if (!rtc.remoteUids.contains(p.user.uid)) return null;
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(
          uid: p.user.uid,
          renderMode: RenderModeType.renderModeHidden,
        ),
        connection: RtcConnection(channelId: rtc.channel),
      ),
    );
  }

  Widget? _notices(RoomState s) {
    final items = <Widget>[
      if (c.error != null)
        _Banner(text: c.error!, action: 'Retry', onTap: c.reconnect),
      if (!s.isAudio && s.premium.enabled && !s.me.premiumAccess)
        _Banner(
          text:
              'Premium room — some cameras are hidden. You can still hear everyone.',
          action: 'Unlock · ${s.premium.priceCoins}',
          onTap: _unlockPremium,
          color: _gold,
        ),
    ];
    return items.isEmpty ? null : Column(children: items);
  }

  Widget _overlay() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _GiftTicker(controller: c),
      const SizedBox(height: 6),
      _CommentPreview(controller: c, onTap: _openComments),
    ],
  );

  Widget _audio(BuildContext context, RoomState s) => AudioRoomView(
    state: s,
    myUuid: c.myUuid,
    isSpeaking: _isSpeaking,
    isMuted: _isMuted,
    micMuted: c.rtc.micMuted,
    speakerOn: c.rtc.speakerOn,
    onCollapse: () => Navigator.of(context).maybePop(),
    onParticipants: _openParticipants,
    onTapParticipant: _participantActions,
    onChat: _openComments,
    onGift: _openGifts,
    onToggleSpeaker: () => c.rtc.setSpeakerOn(!c.rtc.speakerOn),
    onToggleMic: () => _run(c.toggleMic),
    onEnd: _confirmLeave,
    topOverlay: _notices(s),
    bottomOverlay: _overlay(),
  );

  Widget _video(BuildContext context, RoomState s) {
    final rtc = c.rtc;
    final me = s.me;
    return VideoRoomView(
      state: s,
      myUuid: c.myUuid,
      isSpeaking: _isSpeaking,
      isMuted: _isMuted,
      videoFor: _videoFor,
      speakerOn: rtc.speakerOn,
      canFlipCamera: me.onStage && !rtc.cameraOff,
      onBack: () => Navigator.of(context).maybePop(),
      onFlipCamera: rtc.switchCamera,
      onToggleSpeaker: () => rtc.setSpeakerOn(!rtc.speakerOn),
      onTitle: _openParticipants,
      onLeave: _confirmLeave,
      leaveLabel: me.isHost ? 'End' : 'Leave',
      onTapParticipant: _participantActions,
      onUnlock: _unlockPremium,
      onOverflow: _openParticipants,
      topOverlay: _notices(s),
      bottomOverlay: _overlay(),
      tools: [
        if (me.onStage) ...[
          VideoToolItem(
            icon: rtc.micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: rtc.micMuted ? 'Unmute' : 'Mute',
            onTap: () => _run(c.toggleMic),
          ),
          VideoToolItem(
            icon: rtc.cameraOff
                ? Icons.videocam_off_rounded
                : Icons.videocam_rounded,
            label: rtc.cameraOff ? 'Start video' : 'Stop video',
            onTap: () => rtc.setCameraOff(!rtc.cameraOff),
          ),
        ] else if (me.seatRequest == 'pending')
          VideoToolItem(
            icon: Icons.hourglass_top_rounded,
            label: 'Requested',
            onTap: () => _run(c.cancelSeat),
          )
        else
          VideoToolItem(
            icon: Icons.front_hand_rounded,
            label: me.seatFeeCoins > 0
                ? 'Join · ${me.seatFeeCoins}'
                : 'Join camera',
            highlighted: true,
            onTap: _requestSeat,
          ),
        VideoToolItem(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Chat',
          onTap: _openComments,
        ),
        VideoToolItem(
          icon: Icons.card_giftcard_rounded,
          label: 'Gift',
          onTap: _openGifts,
        ),
        VideoToolItem(
          icon: Icons.groups_rounded,
          label: 'People',
          badge: s.participants.length,
          onTap: _openParticipants,
        ),
        if (me.canModerate) ...[
          VideoToolItem(
            icon: Icons.front_hand_outlined,
            label: 'Requests',
            badge: s.seatRequests.length,
            onTap: _openSeatRequests,
          ),
          VideoToolItem(
            icon: Icons.workspace_premium_rounded,
            label: s.premium.enabled ? 'Premium on' : 'Premium',
            highlighted: s.premium.enabled,
            onTap: _openPremium,
          ),
        ],
      ],
    );
  }

  void _openParticipants() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AnimatedBuilder(
        animation: c,
        builder: (b, _) {
          final s = c.state;
          if (s == null) return const SizedBox.shrink();
          String role(RoomParticipant p) => switch (p.role) {
            'host' => 'Host',
            'guest' => 'On camera',
            'speaker' => p.user.isOwner ? 'Owner' : 'In the room',
            _ => p.user.isOwner ? 'Owner · watching' : 'Watching',
          };
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(b).size.height * 0.6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '${s.participants.length} in the room',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final p in s.participants)
                          ListTile(
                            leading: MoonAvatar(p.user, size: 40),
                            title: Text(
                              _isMe(p) ? 'You' : p.user.display,
                              style: TextStyle(
                                color: MoonColors.nameColor(p.user.uuid),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              role(p),
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: _isMuted(p)
                                ? const Icon(
                                    Icons.mic_off_rounded,
                                    color: Colors.white38,
                                  )
                                : SoundWave(active: _isSpeaking(p)),
                            onTap: s.me.canModerate && !p.user.isHost
                                ? () {
                                    Navigator.pop(b);
                                    _participantActions(p);
                                  }
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── top bar / banners ─────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onTap;
  final Color color;

  const _Banner({
    required this.text,
    required this.action,
    required this.onTap,
    this.color = Colors.orangeAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(
              action,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── audio stage ───────────────────────────────────────────────────────

// ── video grid ────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final RoomUser user;
  final double size;
  const _Avatar(this.user, {this.size = 40});

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.white12,
      backgroundImage: url != null && url.isNotEmpty
          ? CachedNetworkImageProvider(url)
          : null,
      child: url == null || url.isEmpty
          ? Text(
              user.display.isNotEmpty ? user.display[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.white, fontSize: size * 0.38),
            )
          : null,
    );
  }
}

// ── bottom controls ───────────────────────────────────────────────────

// ── gifts ─────────────────────────────────────────────────────────────

class _GiftTicker extends StatelessWidget {
  final ClubRoomController controller;
  const _GiftTicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    final recent = controller.gifts
        .where((g) => DateTime.now().difference(g.at).inSeconds < 6)
        .toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    final g = recent.last;
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFB620E0), _accent]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GiftIcon(
              code: g.giftCode,
              imageUrl: g.imageUrl,
              title: g.giftTitle,
              size: 26,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${g.from} sent ${g.quantity > 1 ? '${g.quantity}× ' : ''}${g.giftTitle} to ${g.to}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gift artwork, same as livestream gifts: emoji → bundled SVG → material
/// icon → remote image (most catalog gifts have no image_url).
class _GiftIcon extends StatefulWidget {
  final String code;
  final String? imageUrl;
  final String? title;
  final double size;

  const _GiftIcon({
    required this.code,
    this.imageUrl,
    this.title,
    this.size = 40,
  });

  @override
  State<_GiftIcon> createState() => _GiftIconState();
}

class _GiftIconState extends State<_GiftIcon> {
  late Future<Widget> _visual = _load();

  Future<Widget> _load() => GiftVisuals.build(
    widget.code,
    size: widget.size,
    title: widget.title,
    imageUrl: widget.imageUrl,
  );

  @override
  void didUpdateWidget(covariant _GiftIcon old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code || old.imageUrl != widget.imageUrl) {
      _visual = _load();
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: FutureBuilder<Widget>(
      future: _visual,
      builder: (_, snap) => Center(
        child:
            snap.data ??
            Icon(
              Icons.card_giftcard,
              color: Colors.white54,
              size: widget.size * 0.7,
            ),
      ),
    ),
  );
}

class _GiftSheet extends StatefulWidget {
  final ClubRoomController controller;
  const _GiftSheet({required this.controller});

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  List<GiftItem>? _gifts;
  GiftItem? _selected;
  String _to = 'host';
  int _qty = 1;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller
        .loadGifts()
        .then((g) {
          if (mounted) setState(() => _gifts = g);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = clubApiMessage(e));
        });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.state!;
    final others = s.participants
        .where((p) => p.user.uuid != c.myUuid)
        .toList();
    final hostIsMe = s.host.uuid == c.myUuid;
    final hostHere = others.any((p) => p.user.isHost);
    // Default: the host (for everyone else), or everyone for the host.
    if (_to == 'host' && (hostIsMe || !hostHere)) _to = 'all';
    // The person picked has left → back to everyone.
    if (_to != 'all' &&
        _to != 'host' &&
        !others.any((p) => p.user.uuid == _to)) {
      _to = 'all';
    }
    final recipients = others.length;
    final cost =
        (_selected?.coins ?? 0) * _qty * (_to == 'all' ? recipients : 1);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send a gift',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Send to',
              style: TextStyle(color: Colors.white54, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            if (recipients == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'No one else is in the room yet.',
                  style: TextStyle(color: Colors.white54),
                ),
              )
            else
              SizedBox(
                height: 86,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _recipient(
                      value: 'all',
                      label: 'Everyone',
                      sub: '$recipients',
                      avatar: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: MoonColors.dusk,
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    if (!hostIsMe && hostHere)
                      _recipient(
                        value: 'host',
                        label: 'Host',
                        sub: s.host.display,
                        avatar: MoonAvatar(s.host, size: 52),
                        badge: Icons.nightlight_round,
                      ),
                    for (final p in others)
                      if (!p.user.isHost)
                        _recipient(
                          value: p.user.uuid,
                          label: p.user.display,
                          avatar: MoonAvatar(p.user, size: 52),
                          badge: p.user.isOwner
                              ? Icons.workspace_premium_rounded
                              : null,
                        ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: _gifts == null
                  ? Center(
                      child: _error != null
                          ? Text(
                              _error!,
                              style: const TextStyle(color: Colors.white54),
                            )
                          : const AppLogoLoader(),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.8,
                          ),
                      itemCount: _gifts!.length,
                      itemBuilder: (_, i) {
                        final g = _gifts![i];
                        final sel = _selected?.code == g.code;
                        return GestureDetector(
                          onTap: () => setState(() => _selected = g),
                          child: Container(
                            decoration: BoxDecoration(
                              color: sel
                                  ? _accent.withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel ? _accent : Colors.transparent,
                              ),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: _GiftIcon(
                                      code: g.code,
                                      imageUrl: g.imageUrl,
                                      title: g.title,
                                      size: 40,
                                    ),
                                  ),
                                ),
                                Text(
                                  g.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '${g.coins}',
                                  style: const TextStyle(
                                    color: _gold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$_qty',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                IconButton(
                  onPressed: _qty < 99 ? () => setState(() => _qty++) : null,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _selected == null || _sending || recipients == 0
                      ? null
                      : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_sending ? 'Sending…' : 'Send · $cost coins'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipient({
    required String value,
    required String label,
    required Widget avatar,
    String? sub,
    IconData? badge,
  }) {
    final selected = _to == value;
    return GestureDetector(
      onTap: () => setState(() => _to = value),
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? MoonColors.dusk : null,
                    color: selected ? null : Colors.white12,
                  ),
                  child: ClipOval(child: avatar),
                ),
                if (badge != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: MoonColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: _panel, width: 2),
                      ),
                      child: Icon(badge, size: 11, color: MoonColors.night),
                    ),
                  ),
                if (selected)
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.check,
                        size: 13,
                        color: MoonColors.night,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              sub != null && value == 'all' ? '$label ($sub)' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await widget.controller.sendGift(_selected!, _to, quantity: _qty);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) await showCoinError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

// ── premium (host / owner) ────────────────────────────────────────────

class _PremiumSheet extends StatefulWidget {
  final RoomPremium current;
  const _PremiumSheet({required this.current});

  @override
  State<_PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends State<_PremiumSheet> {
  late bool _on = widget.current.enabled;
  late final _price = TextEditingController(
    text: widget.current.priceCoins > 0 ? '${widget.current.priceCoins}' : '50',
  );
  late String _mode = widget.current.mode ?? 'host_only';

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _on,
            onChanged: (v) => setState(() => _on = v),
            activeThumbColor: _gold,
            title: const Text(
              'Premium video',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'Men pay to see the premium cameras. Ladies watch free. Everyone still hears the sound.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          if (_on) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Price (coins)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v ?? 'host_only'),
              child: const Column(
                children: [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'host_only',
                    title: Text(
                      'Only my camera is premium',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'host_and_ladies',
                    title: Text(
                      'My camera + every lady on camera',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final price = int.tryParse(_price.text.trim()) ?? 0;
                if (_on && price < 1) {
                  TopSnack.error(context, 'Enter a price of at least 1 coin');
                  return;
                }
                Navigator.of(context).pop((_on, price, _mode));
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── comments ──────────────────────────────────────────────────────────

class _CommentPreview extends StatelessWidget {
  final ClubRoomController controller;
  final VoidCallback onTap;
  const _CommentPreview({required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final last = controller.comments.length > 4
        ? controller.comments.sublist(controller.comments.length - 4)
        : controller.comments;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in last)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${c.user?.display ?? 'Member'}  ',
                      style: const TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text:
                          c.body ??
                          (c.mediaType == 'video' ? '🎬 video' : '📷 photo'),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Write a comment…',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final ClubRoomController controller;
  const _CommentsSheet({required this.controller});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  RoomComment? _replyTo;
  RoomComment? _editing;
  File? _media;
  bool _mediaIsVideo = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scrollToEnd);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scrollToEnd);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickMedia() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _panel,
      builder: (b) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.white),
              title: const Text('Photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(b, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text('Video', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(b, 'video'),
            ),
          ],
        ),
      ),
    );
    if (kind == null) return;
    final picker = ImagePicker();
    final file = kind == 'video'
        ? await picker.pickVideo(
            source: ImageSource.gallery,
            maxDuration: const Duration(minutes: 2),
          )
        : await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1600,
            imageQuality: 85,
          );
    if (file == null) return;
    setState(() {
      _media = File(file.path);
      _mediaIsVideo = kind == 'video';
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty && _media == null) return;
    setState(() => _sending = true);
    try {
      if (_editing != null) {
        await widget.controller.editComment(_editing!.uuid, text);
      } else {
        await widget.controller.postComment(
          body: text,
          replyTo: _replyTo?.uuid,
          media: _media,
        );
      }
      _input.clear();
      setState(() {
        _replyTo = null;
        _editing = null;
        _media = null;
      });
    } catch (e) {
      if (mounted)
        TopSnack.error(context, clubApiMessage(e, 'Could not send.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _actions(RoomComment cm) {
    final c = widget.controller;
    final mine = cm.user?.uuid == c.myUuid;
    final canDelete = mine || (c.state?.me.canModerate ?? false);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      builder: (b) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white),
              title: const Text('Reply', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(b);
                setState(() {
                  _replyTo = cm;
                  _editing = null;
                });
              },
            ),
            if (mine && cm.body != null)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text(
                  'Edit',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(b);
                  setState(() {
                    _editing = cm;
                    _replyTo = null;
                    _media = null;
                    _input.text = cm.body ?? '';
                  });
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(b);
                  try {
                    await c.deleteComment(cm.uuid);
                  } catch (e) {
                    if (mounted) TopSnack.error(context, clubApiMessage(e));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final comments = widget.controller.comments;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Comments',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: comments.isEmpty
                  ? const Center(
                      child: Text(
                        'No comments yet — say hi 👋',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: comments.length,
                      itemBuilder: (_, i) => _CommentTile(
                        comment: comments[i],
                        onLongPress: () => _actions(comments[i]),
                      ),
                    ),
            ),
            if (_replyTo != null || _editing != null || _media != null)
              Container(
                color: Colors.white.withValues(alpha: 0.05),
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                child: Row(
                  children: [
                    Icon(
                      _editing != null
                          ? Icons.edit
                          : (_media != null
                                ? (_mediaIsVideo ? Icons.videocam : Icons.photo)
                                : Icons.reply),
                      color: _accent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _editing != null
                            ? 'Editing your comment'
                            : _replyTo != null
                            ? 'Replying to ${_replyTo!.user?.display ?? 'comment'}'
                                  '${_media != null ? ' · ${_mediaIsVideo ? 'video' : 'photo'} attached' : ''}'
                            : '${_mediaIsVideo ? 'Video' : 'Photo'} attached',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: () => setState(() {
                        if (_editing != null) _input.clear();
                        _replyTo = null;
                        _editing = null;
                        _media = null;
                      }),
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                child: Row(
                  children: [
                    if (_editing == null)
                      IconButton(
                        icon: const Icon(
                          Icons.attach_file,
                          color: Colors.white70,
                        ),
                        onPressed: _sending ? null : _pickMedia,
                      ),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Write a comment…',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white10,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: AppLogoLoader(),
                            )
                          : const Icon(Icons.send_rounded, color: _accent),
                      onPressed: _sending ? null : _send,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final RoomComment comment;
  final VoidCallback onLongPress;
  const _CommentTile({required this.comment, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final c = comment;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.user != null) _Avatar(c.user!, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.user?.display ?? 'Member',
                          style: const TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      if (c.edited)
                        const Text(
                          '  · edited',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                    ],
                  ),
                  if (c.replyToUuid != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(
                          left: BorderSide(color: _accent, width: 2),
                        ),
                      ),
                      child: Text(
                        c.replyToDeleted
                            ? 'Comment deleted'
                            : '${c.replyToUser ?? ''}: ${c.replyToBody ?? '(media)'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  if (c.body != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        c.body!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  if (c.mediaUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: c.mediaType == 'video'
                          ? _VideoThumb(url: c.mediaUrl!)
                          : GestureDetector(
                              onTap: () => _openImage(context, c.mediaUrl!),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: c.mediaUrl!,
                                  height: 160,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url)),
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  final String url;
  const _VideoThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: _InlineVideo(url: url),
        ),
      ),
      child: Container(
        height: 120,
        width: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 44),
        ),
      ),
    );
  }
}

class _InlineVideo extends StatefulWidget {
  final String url;
  const _InlineVideo({required this.url});

  @override
  State<_InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<_InlineVideo> {
  late final VideoPlayerController _v = VideoPlayerController.networkUrl(
    Uri.parse(widget.url),
  );

  @override
  void initState() {
    super.initState();
    _v.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _v.play();
      }
    });
  }

  @override
  void dispose() {
    _v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_v.value.isInitialized) {
      return const SizedBox(height: 220, child: Center(child: AppLogoLoader()));
    }
    return GestureDetector(
      onTap: () => setState(() => _v.value.isPlaying ? _v.pause() : _v.play()),
      child: AspectRatio(
        aspectRatio: _v.value.aspectRatio,
        child: VideoPlayer(_v),
      ),
    );
  }
}
