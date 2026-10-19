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
import 'meet_layout.dart';

const _bg = Color(0xFF0B0A1F);
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
        backgroundColor: _bg,
        body: s == null || _opening
            ? const Center(child: AppLogoLoader())
            : SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      state: s,
                      onClose: () => Navigator.of(context).maybePop(),
                      onRequests: s.me.canModerate && !s.isAudio
                          ? _openSeatRequests
                          : null,
                      onPremium: s.me.canModerate && !s.isAudio
                          ? _openPremium
                          : null,
                    ),
                    if (c.error != null)
                      _Banner(
                        text: c.error!,
                        action: 'Retry',
                        onTap: c.reconnect,
                      ),
                    if (!s.isAudio && s.premium.enabled && !s.me.premiumAccess)
                      _Banner(
                        text:
                            'Premium room — some cameras are hidden. You can still hear everyone.',
                        action: 'Unlock · ${s.premium.priceCoins}',
                        onTap: _unlockPremium,
                        color: _gold,
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: s.isAudio
                                ? _AudioStage(
                                    controller: c,
                                    onTapParticipant: _participantActions,
                                  )
                                : _VideoGrid(
                                    controller: c,
                                    onTapParticipant: _participantActions,
                                    onUnlock: _unlockPremium,
                                  ),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 8,
                            child: _CommentPreview(
                              controller: c,
                              onTap: _openComments,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 12,
                            right: 12,
                            child: _GiftTicker(controller: c),
                          ),
                        ],
                      ),
                    ),
                    _Controls(
                      controller: c,
                      onLeave: _confirmLeave,
                      onComments: _openComments,
                      onGift: _openGifts,
                      onRequestSeat: _requestSeat,
                      onCancelSeat: () => _run(c.cancelSeat),
                      run: _run,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── top bar / banners ─────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final RoomState state;
  final VoidCallback onClose;
  final VoidCallback? onRequests;
  final VoidCallback? onPremium;

  const _TopBar({
    required this.state,
    required this.onClose,
    this.onRequests,
    this.onPremium,
  });

  @override
  Widget build(BuildContext context) {
    final s = state;
    final count = s.participants.length;
    final subtitle = s.isAudio
        ? '$count / ${s.capacity} in the room'
              '${s.freeSlotsLeft > 0 ? ' · ${s.freeSlotsLeft} free places left' : ' · entry ${s.entryFeeCoins} coins'}'
        : '${s.onStage.length} / ${s.capacity} on camera · $count watching';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      s.isAudio ? Icons.graphic_eq : Icons.videocam,
                      color: _accent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        s.title?.isNotEmpty == true
                            ? s.title!
                            : '${s.clubName} · ${s.isAudio ? 'Audio' : 'Video'} room',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (s.premium.enabled) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.workspace_premium,
                        color: _gold,
                        size: 16,
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onPremium != null)
            IconButton(
              tooltip: 'Premium',
              icon: Icon(
                Icons.workspace_premium,
                color: s.premium.enabled ? _gold : Colors.white70,
              ),
              onPressed: onPremium,
            ),
          if (onRequests != null)
            IconButton(
              tooltip: 'Camera requests',
              onPressed: onRequests,
              icon: Badge(
                isLabelVisible: s.seatRequests.isNotEmpty,
                label: Text('${s.seatRequests.length}'),
                child: const Icon(Icons.front_hand, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

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

class _AudioStage extends StatelessWidget {
  final ClubRoomController controller;
  final void Function(RoomParticipant) onTapParticipant;

  const _AudioStage({required this.controller, required this.onTapParticipant});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.rtc,
      builder: (context, _) {
        final s = controller.state!;
        final me = controller.myUuid;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 140),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 18,
            crossAxisSpacing: 8,
            childAspectRatio: 0.72,
          ),
          itemCount: s.participants.length,
          itemBuilder: (context, i) {
            final p = s.participants[i];
            final isMe = p.user.uuid == me;
            final speaking =
                controller.rtc.speaking[isMe ? 0 : p.user.uid] == true &&
                !(isMe ? controller.rtc.micMuted : p.micMuted);
            return GestureDetector(
              onTap: () => onTapParticipant(p),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: speaking
                                ? Colors.greenAccent
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: _Avatar(p.user, size: 60),
                      ),
                      if (isMe ? controller.rtc.micMuted : p.micMuted)
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.redAccent,
                            child: Icon(
                              Icons.mic_off,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isMe ? 'You' : p.user.display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  if (p.user.isHost || p.user.isOwner)
                    Text(
                      p.user.isHost ? 'Host' : 'Owner',
                      style: const TextStyle(color: _accent, fontSize: 10.5),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── video grid ────────────────────────────────────────────────────────

class _VideoGrid extends StatelessWidget {
  final ClubRoomController controller;
  final void Function(RoomParticipant) onTapParticipant;
  final VoidCallback onUnlock;

  const _VideoGrid({
    required this.controller,
    required this.onTapParticipant,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.rtc,
      builder: (context, _) {
        final s = controller.state!;
        final tiles = s.onStage;
        final me = controller.myUuid;
        final mine = tiles.where((p) => p.user.uuid == me).firstOrNull;

        Widget tile(RoomParticipant p, {bool compact = false}) => _VideoTile(
          key: ValueKey(p.user.uuid),
          controller: controller,
          p: p,
          compact: compact,
          onTap: () => onTapParticipant(p),
          onUnlock: onUnlock,
        );

        return LayoutBuilder(
          builder: (context, box) {
            final full = Size(box.maxWidth, box.maxHeight);

            // Meet 1:1 — the other person fills the screen, you float in
            // a small corner preview.
            if (tiles.length == 2 && mine != null) {
              final other = tiles.firstWhere((p) => p != mine);
              return Stack(
                children: [
                  Positioned.fill(child: tile(other)),
                  _FloatingSelfView(
                    area: full,
                    child: tile(mine, compact: true),
                  ),
                ],
              );
            }

            // Leave the comment preview room once the screen is shared.
            final bottom = tiles.length > 2 ? 96.0 : 0.0;
            final area = Size(full.width - 8, full.height - bottom - 8);
            final grid = meetGrid(tiles.length, area);
            return Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, bottom + 4),
              child: Stack(
                children: [
                  for (var i = 0; i < tiles.length; i++)
                    AnimatedPositioned(
                      key: ValueKey('pos-${tiles[i].user.uuid}'),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      left: grid.origins[i].dx,
                      top: grid.origins[i].dy,
                      width: grid.cell.width,
                      height: grid.cell.height,
                      child: tile(tiles[i], compact: tiles.length > 4),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Draggable self-preview for 1:1 video (snaps to the nearest corner).
class _FloatingSelfView extends StatefulWidget {
  final Size area;
  final Widget child;
  const _FloatingSelfView({required this.area, required this.child});

  @override
  State<_FloatingSelfView> createState() => _FloatingSelfViewState();
}

class _FloatingSelfViewState extends State<_FloatingSelfView> {
  static const _margin = 12.0;
  Alignment _corner = Alignment.topRight;
  Offset? _drag;

  Size get _size {
    final w = (widget.area.shortestSide * 0.3).clamp(96.0, 180.0);
    return Size(w, w * 4 / 3);
  }

  Offset _cornerOffset(Alignment a) {
    final s = _size;
    final x = a.x < 0 ? _margin : widget.area.width - s.width - _margin;
    final y = a.y < 0 ? _margin : widget.area.height - s.height - 110;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final s = _size;
    final pos = _drag ?? _cornerOffset(_corner);
    return AnimatedPositioned(
      duration: _drag == null
          ? const Duration(milliseconds: 200)
          : Duration.zero,
      curve: Curves.easeOut,
      left: pos.dx,
      top: pos.dy,
      width: s.width,
      height: s.height,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _drag = (_drag ?? pos) + d.delta),
        onPanEnd: (_) {
          final p = _drag ?? pos;
          final cx = p.dx + s.width / 2;
          final cy = p.dy + s.height / 2;
          setState(() {
            _corner = Alignment(
              cx < widget.area.width / 2 ? -1 : 1,
              cy < widget.area.height / 2 ? -1 : 1,
            );
            _drag = null;
          });
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final ClubRoomController controller;
  final RoomParticipant p;
  final VoidCallback onTap;
  final VoidCallback onUnlock;

  /// Small tile (floating self-view, or a busy grid): smaller labels.
  final bool compact;

  const _VideoTile({
    super.key,
    required this.controller,
    required this.p,
    required this.onTap,
    required this.onUnlock,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final rtc = controller.rtc;
    final engine = rtc.engine;
    final isMe = p.user.uuid == controller.myUuid;
    final locked = !p.videoVisible && !isMe;

    Widget video;
    if (locked) {
      video = _LockedTile(user: p.user, onUnlock: onUnlock);
    } else if (engine == null || !rtc.joined) {
      video = _AvatarTile(user: p.user);
    } else if (isMe) {
      video = rtc.cameraOff
          ? _AvatarTile(user: p.user)
          : AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: engine,
                // Cover: fill the tile and crop, never letterbox.
                canvas: const VideoCanvas(
                  uid: 0,
                  renderMode: RenderModeType.renderModeHidden,
                ),
              ),
            );
    } else if (rtc.remoteUids.contains(p.user.uid)) {
      video = AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(
            uid: p.user.uid,
            renderMode: RenderModeType.renderModeHidden,
          ),
          connection: RtcConnection(channelId: rtc.channel),
        ),
      );
    } else {
      video = _AvatarTile(user: p.user);
    }

    final speaking = rtc.speaking[isMe ? 0 : p.user.uid] == true;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: speaking ? Colors.greenAccent : Colors.white10,
            width: speaking ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            video,
            Positioned(
              left: 6,
              bottom: 6,
              right: 6,
              child: Row(
                children: [
                  if (p.micMuted)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.mic_off,
                        size: 14,
                        color: Colors.redAccent,
                      ),
                    ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isMe ? 'You' : p.user.display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 10 : 12,
                        ),
                      ),
                    ),
                  ),
                  if (p.videoPremium) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.workspace_premium, color: _gold, size: 14),
                  ],
                ],
              ),
            ),
            if (p.user.isHost && !compact)
              const Positioned(top: 6, left: 6, child: _Chip('HOST', _accent)),
          ],
        ),
      ),
    );
  }
}

class _LockedTile extends StatelessWidget {
  final RoomUser user;
  final VoidCallback onUnlock;
  const _LockedTile({required this.user, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (user.avatarUrl != null)
          ImageFiltered(
            imageFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.6),
              BlendMode.darken,
            ),
            child: CachedNetworkImage(
              imageUrl: user.avatarUrl!,
              fit: BoxFit.cover,
            ),
          ),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, color: _gold, size: 28),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onUnlock,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: _gold,
                  ),
                  child: const Text('Unlock premium'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarTile extends StatelessWidget {
  final RoomUser user;
  const _AvatarTile({required this.user});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Center(
      child: _Avatar(
        user,
        size: (box.biggest.shortestSide * 0.42).clamp(28.0, 96.0),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

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

class _Controls extends StatelessWidget {
  final ClubRoomController controller;
  final VoidCallback onLeave;
  final VoidCallback onComments;
  final VoidCallback onGift;
  final VoidCallback onRequestSeat;
  final VoidCallback onCancelSeat;
  final Future<void> Function(Future<void> Function()) run;

  const _Controls({
    required this.controller,
    required this.onLeave,
    required this.onComments,
    required this.onGift,
    required this.onRequestSeat,
    required this.onCancelSeat,
    required this.run,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.rtc,
      builder: (context, _) {
        final s = controller.state!;
        final rtc = controller.rtc;
        final onStage = s.me.onStage;
        return Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          color: _panel,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (onStage)
                _RoundBtn(
                  icon: rtc.micMuted ? Icons.mic_off : Icons.mic,
                  label: rtc.micMuted ? 'Unmute' : 'Mute',
                  active: !rtc.micMuted,
                  onTap: () => run(controller.toggleMic),
                ),
              if (onStage && !s.isAudio) ...[
                _RoundBtn(
                  icon: rtc.cameraOff ? Icons.videocam_off : Icons.videocam,
                  label: 'Camera',
                  active: !rtc.cameraOff,
                  onTap: () => rtc.setCameraOff(!rtc.cameraOff),
                ),
                _RoundBtn(
                  icon: Icons.cameraswitch,
                  label: 'Flip',
                  onTap: rtc.switchCamera,
                ),
              ],
              if (!onStage && !s.isAudio)
                s.me.seatRequest == 'pending'
                    ? _RoundBtn(
                        icon: Icons.hourglass_top,
                        label: 'Requested',
                        onTap: onCancelSeat,
                      )
                    : _RoundBtn(
                        icon: Icons.front_hand,
                        label: s.me.seatFeeCoins > 0
                            ? 'Join · ${s.me.seatFeeCoins}'
                            : 'Join camera',
                        active: true,
                        onTap: onRequestSeat,
                      ),
              _RoundBtn(
                icon: Icons.chat_bubble_outline,
                label: 'Comments',
                onTap: onComments,
              ),
              _RoundBtn(
                icon: Icons.card_giftcard,
                label: 'Gift',
                onTap: onGift,
              ),
              _RoundBtn(
                icon: Icons.call_end,
                label: s.me.isHost ? 'End' : 'Leave',
                danger: true,
                onTap: onLeave,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  const _RoundBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? Colors.redAccent
        : (active ? _accent : Colors.white.withValues(alpha: 0.1));
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: bg,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

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
    if (hostIsMe && _to == 'host') _to = 'all';
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
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (!hostIsMe) _choice('Host (${s.host.display})', 'host'),
                  _choice('Everyone ($recipients)', 'all'),
                  for (final p in others)
                    if (!p.user.isHost) _choice(p.user.display, p.user.uuid),
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
                  onPressed:
                      _selected == null ||
                          _sending ||
                          (_to == 'all' && recipients == 0)
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

  Widget _choice(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _to == value,
      onSelected: (_) => setState(() => _to = value),
      selectedColor: _accent,
      labelStyle: TextStyle(
        color: _to == value ? Colors.white : Colors.white70,
      ),
      backgroundColor: Colors.white10,
    ),
  );

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
