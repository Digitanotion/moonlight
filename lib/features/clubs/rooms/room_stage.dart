// lib/features/clubs/rooms/room_stage.dart
//
// The look of a club room, kept free of Agora / API code so the real screen
// and the design preview render exactly the same widgets.
//
//  • AudioRoomView — group voice call: big round avatars in a 3-column
//    grid; whoever is talking gets Moonlight's dusk-gradient ring and a
//    live sound wave; muted people get a mic-off badge. Floating pill of
//    controls at the bottom.
//  • VideoRoomView — group video call: rounded camera tiles (Meet-style
//    tiling), each with a name chip carrying a live sound wave or a mic-off
//    icon; host badge; premium lock; "+N" tile when more people are on
//    camera than fit. Labelled toolbar at the bottom.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'club_room_models.dart';
import 'meet_layout.dart';

// ── Moonlight palette ───────────────────────────────────────────────────

class MoonColors {
  static const night = Color(0xFF0A0920);
  static const nightTop = Color(0xFF1B1446);
  static const surface = Color(0xFF17142E);
  static const tile = Color(0xFF221D44);
  static const violet = Color(0xFF8E2DE2);
  static const magenta = Color(0xFFE0418A);
  static const ember = Color(0xFFFF7A00);
  static const gold = Color(0xFFFFC107);
  static const danger = Color(0xFFFF3B5C);

  /// Moonlight's dusk gradient: violet → magenta → ember.
  static const dusk = LinearGradient(
    colors: [violet, magenta, ember],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const background = LinearGradient(
    colors: [nightTop, night],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Stable per-person name colour (like WhatsApp group calls).
  static const _names = [
    Color(0xFFFF8FB1),
    Color(0xFF7FDBCA),
    Color(0xFFFFC46B),
    Color(0xFFB39DFF),
    Color(0xFF8FD3FF),
    Color(0xFFFF9E7A),
    Color(0xFFA5E887),
    Color(0xFFF7A8FF),
  ];

  static Color nameColor(String key) =>
      _names[key.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff) %
          _names.length];
}

// ── sound wave ──────────────────────────────────────────────────────────

/// Live audio indicator: bars that dance while [active], resting dots when
/// silent. Painted in the dusk gradient by default.
class SoundWave extends StatefulWidget {
  final bool active;
  final double height;
  final int bars;
  final Gradient gradient;

  const SoundWave({
    super.key,
    required this.active,
    this.height = 14,
    this.bars = 4,
    this.gradient = const LinearGradient(
      colors: [Color(0xFF7CFFCB), Color(0xFF39D98A)],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    ),
  });

  @override
  State<SoundWave> createState() => _SoundWaveState();
}

class _SoundWaveState extends State<SoundWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant SoundWave old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barW = (widget.height / 5).clamp(2.0, 4.0);
    final gap = barW * 0.8;
    return SizedBox(
      height: widget.height,
      width: widget.bars * barW + (widget.bars - 1) * gap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => ShaderMask(
          shaderCallback: (r) => widget.gradient.createShader(r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.bars; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Container(
                  width: barW,
                  height: widget.active
                      ? widget.height *
                            (0.3 +
                                0.7 *
                                    (0.5 +
                                            0.5 *
                                                math.sin(
                                                  _c.value * 2 * math.pi +
                                                      i * 1.7,
                                                ))
                                        .abs())
                      : barW,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(barW),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── avatar ──────────────────────────────────────────────────────────────

class MoonAvatar extends StatelessWidget {
  final RoomUser user;
  final double size;
  const MoonAvatar(this.user, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    final initial = user.display.isNotEmpty
        ? user.display.characters.first.toUpperCase()
        : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            MoonColors.nameColor(user.uuid).withValues(alpha: 0.85),
            MoonColors.violet.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _Initial(initial, size),
            )
          : _Initial(initial, size),
    );
  }
}

class _Initial extends StatelessWidget {
  final String text;
  final double size;
  const _Initial(this.text, this.size);

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.4,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ── shared bits ─────────────────────────────────────────────────────────

class _CallClock extends StatefulWidget {
  final DateTime? since;
  final TextStyle style;
  const _CallClock({required this.since, required this.style});

  @override
  State<_CallClock> createState() => _CallClockState();
}

class _CallClockState extends State<_CallClock> {
  late final Stream<int> _tick = Stream.periodic(
    const Duration(seconds: 1),
    (i) => i,
  );

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    if (since == null) return const SizedBox.shrink();
    return StreamBuilder<int>(
      stream: _tick,
      builder: (_, _) {
        final d = DateTime.now().difference(since.toLocal());
        return Text(
          _fmt(d.isNegative ? Duration.zero : d),
          style: widget.style,
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color background;
  final Color color;
  final Gradient? gradient;
  final String? tooltip;

  const _CircleIconButton({
    required this.icon,
    this.onTap,
    this.size = 48,
    this.background = const Color(0x22FFFFFF),
    this.color = Colors.white,
    this.gradient,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: gradient == null ? background : null,
          gradient: gradient,
        ),
        child: Icon(icon, color: color, size: size * 0.46),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

String _youOr(RoomUser u, String? me) => u.uuid == me ? 'You' : u.display;

// ── AUDIO ROOM ──────────────────────────────────────────────────────────

class AudioRoomView extends StatelessWidget {
  final RoomState state;
  final String? myUuid;
  final bool Function(RoomParticipant p) isSpeaking;
  final bool Function(RoomParticipant p) isMuted;

  final bool micMuted;
  final bool speakerOn;
  final VoidCallback onCollapse;
  final VoidCallback onParticipants;
  final void Function(RoomParticipant p) onTapParticipant;
  final VoidCallback onChat;
  final VoidCallback onGift;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleMic;
  final VoidCallback onEnd;

  /// Optional overlays (gift banner, comment preview, notices).
  final Widget? topOverlay;
  final Widget? bottomOverlay;

  const AudioRoomView({
    super.key,
    required this.state,
    required this.myUuid,
    required this.isSpeaking,
    required this.isMuted,
    required this.micMuted,
    required this.speakerOn,
    required this.onCollapse,
    required this.onParticipants,
    required this.onTapParticipant,
    required this.onChat,
    required this.onGift,
    required this.onToggleSpeaker,
    required this.onToggleMic,
    required this.onEnd,
    this.topOverlay,
    this.bottomOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final s = state;
    final title = s.title?.isNotEmpty == true ? s.title! : s.clubName;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: MoonColors.background),
      child: SafeArea(
        child: Stack(
          children: [
            // Soft moon glow behind the grid — Moonlight's signature.
            Positioned(
              top: -120,
              right: -80,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        MoonColors.violet.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        size: 40,
                        onTap: onCollapse,
                        tooltip: 'Minimise',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.nightlight_round,
                                  color: MoonColors.gold,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${s.participants.length} joined · ',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12.5,
                                  ),
                                ),
                                _CallClock(
                                  since: s.startedAt,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12.5,
                                    fontFeatures: [
                                      ui.FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CircleIconButton(
                        icon: Icons.groups_rounded,
                        size: 40,
                        onTap: onParticipants,
                        tooltip: 'People',
                      ),
                    ],
                  ),
                ),
                if (topOverlay != null) topOverlay!,
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final cellW = (box.maxWidth - 24) / 3;
                      final avatar = (cellW * 0.74).clamp(64.0, 112.0);
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 190),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 14,
                          mainAxisExtent: avatar + 44,
                        ),
                        itemCount: s.participants.length,
                        itemBuilder: (_, i) {
                          final p = s.participants[i];
                          return _AudioSeat(
                            p: p,
                            label: _youOr(p.user, myUuid),
                            size: avatar,
                            speaking: isSpeaking(p),
                            muted: isMuted(p),
                            onTap: () => onTapParticipant(p),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            if (bottomOverlay != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 104,
                child: bottomOverlay!,
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Center(
                child: _AudioControlPill(
                  micMuted: micMuted,
                  speakerOn: speakerOn,
                  onChat: onChat,
                  onGift: onGift,
                  onToggleSpeaker: onToggleSpeaker,
                  onToggleMic: onToggleMic,
                  onEnd: onEnd,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioSeat extends StatelessWidget {
  final RoomParticipant p;
  final String label;
  final double size;
  final bool speaking;
  final bool muted;
  final VoidCallback onTap;

  const _AudioSeat({
    required this.p,
    required this.label,
    required this.size,
    required this.speaking,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ring = size + 8;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          SizedBox(
            width: ring,
            height: ring + 4,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Speaking: dusk ring + glow.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: ring,
                  height: ring,
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: speaking ? MoonColors.dusk : null,
                    color: speaking ? null : Colors.transparent,
                    boxShadow: speaking
                        ? [
                            BoxShadow(
                              color: MoonColors.magenta.withValues(alpha: 0.55),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: MoonColors.night,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: MoonAvatar(p.user, size: size),
                  ),
                ),
                if (speaking)
                  Positioned(
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MoonColors.night,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MoonColors.magenta.withValues(alpha: 0.7),
                        ),
                      ),
                      child: const SoundWave(
                        active: true,
                        height: 11,
                        bars: 5,
                        gradient: MoonColors.dusk,
                      ),
                    ),
                  )
                else if (muted)
                  Positioned(
                    right: 2,
                    bottom: 4,
                    child: Container(
                      width: size * 0.3,
                      height: size * 0.3,
                      decoration: BoxDecoration(
                        color: const Color(0xE6221D44),
                        shape: BoxShape.circle,
                        border: Border.all(color: MoonColors.night, width: 2),
                      ),
                      child: Icon(
                        Icons.mic_off_rounded,
                        color: Colors.white70,
                        size: size * 0.16,
                      ),
                    ),
                  ),
                if (p.user.isHost || p.user.isOwner)
                  Positioned(
                    top: 0,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: MoonColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: MoonColors.night, width: 2),
                      ),
                      child: Icon(
                        p.user.isHost
                            ? Icons.nightlight_round
                            : Icons.workspace_premium_rounded,
                        size: 12,
                        color: MoonColors.night,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: speaking
                  ? Colors.white
                  : MoonColors.nameColor(p.user.uuid),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioControlPill extends StatelessWidget {
  final bool micMuted;
  final bool speakerOn;
  final VoidCallback onChat;
  final VoidCallback onGift;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleMic;
  final VoidCallback onEnd;

  const _AudioControlPill({
    required this.micMuted,
    required this.speakerOn,
    required this.onChat,
    required this.onGift,
    required this.onToggleSpeaker,
    required this.onToggleMic,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircleIconButton(
                icon: Icons.chat_bubble_rounded,
                onTap: onChat,
                tooltip: 'Comments',
              ),
              const SizedBox(width: 12),
              _CircleIconButton(
                icon: Icons.card_giftcard_rounded,
                onTap: onGift,
                tooltip: 'Send a gift',
              ),
              const SizedBox(width: 12),
              _CircleIconButton(
                icon: speakerOn
                    ? Icons.volume_up_rounded
                    : Icons.hearing_rounded,
                onTap: onToggleSpeaker,
                tooltip: speakerOn ? 'Speaker' : 'Earpiece',
              ),
              const SizedBox(width: 12),
              _CircleIconButton(
                icon: micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                size: 54,
                onTap: onToggleMic,
                background: Colors.white,
                color: MoonColors.night,
                gradient: micMuted ? null : MoonColors.dusk,
                tooltip: micMuted ? 'Unmute' : 'Mute',
              ),
              const SizedBox(width: 12),
              _CircleIconButton(
                icon: Icons.call_end_rounded,
                size: 54,
                onTap: onEnd,
                background: MoonColors.danger,
                tooltip: 'Leave',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── VIDEO ROOM ──────────────────────────────────────────────────────────

class VideoToolItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
  final int badge;

  const VideoToolItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.badge = 0,
  });
}

class VideoRoomView extends StatelessWidget {
  final RoomState state;
  final String? myUuid;
  final bool Function(RoomParticipant p) isSpeaking;
  final bool Function(RoomParticipant p) isMuted;

  /// Live camera for a person, or null to show their avatar.
  final Widget? Function(RoomParticipant p) videoFor;

  final bool speakerOn;
  final bool canFlipCamera;
  final VoidCallback onBack;
  final VoidCallback onFlipCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onTitle;
  final VoidCallback onLeave;
  final String leaveLabel;
  final void Function(RoomParticipant p) onTapParticipant;
  final VoidCallback onUnlock;
  final VoidCallback onOverflow;
  final List<VideoToolItem> tools;

  final Widget? topOverlay;
  final Widget? bottomOverlay;

  /// Most tiles shown at once before the "+N" tile.
  final int maxTiles;

  const VideoRoomView({
    super.key,
    required this.state,
    required this.myUuid,
    required this.isSpeaking,
    required this.isMuted,
    required this.videoFor,
    required this.speakerOn,
    required this.canFlipCamera,
    required this.onBack,
    required this.onFlipCamera,
    required this.onToggleSpeaker,
    required this.onTitle,
    required this.onLeave,
    required this.leaveLabel,
    required this.onTapParticipant,
    required this.onUnlock,
    required this.onOverflow,
    required this.tools,
    this.topOverlay,
    this.bottomOverlay,
    this.maxTiles = 10, // the video room holds 10 on camera
  });

  @override
  Widget build(BuildContext context) {
    final s = state;
    return ColoredBox(
      color: MoonColors.night,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _VideoTopBar(
              title: s.title?.isNotEmpty == true ? s.title! : s.clubName,
              premium: s.premium.enabled,
              speakerOn: speakerOn,
              canFlipCamera: canFlipCamera,
              onBack: onBack,
              onFlipCamera: onFlipCamera,
              onToggleSpeaker: onToggleSpeaker,
              onTitle: onTitle,
              onLeave: onLeave,
              leaveLabel: leaveLabel,
            ),
            if (topOverlay != null) topOverlay!,
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    // Keep the comments' strip clear so they never sit on
                    // a face; the grid shrinks to fit above it.
                    bottom: bottomOverlay != null ? 92 : 0,
                    child: _grid(context),
                  ),
                  if (bottomOverlay != null)
                    Positioned(
                      left: 10,
                      right: 90,
                      bottom: 10,
                      child: bottomOverlay!,
                    ),
                ],
              ),
            ),
            _VideoToolbar(tools: tools),
          ],
        ),
      ),
    );
  }

  Widget _grid(BuildContext context) {
    final onCam = state.onStage;

    Widget tile(RoomParticipant p, {bool compact = false}) => VideoTileView(
      key: ValueKey(p.user.uuid),
      p: p,
      label: _youOr(p.user, myUuid),
      speaking: isSpeaking(p),
      muted: isMuted(p),
      locked: !p.videoVisible && p.user.uuid != myUuid,
      video: videoFor(p),
      compact: compact,
      onTap: () => onTapParticipant(p),
      onUnlock: onUnlock,
    );

    return LayoutBuilder(
      builder: (context, box) {
        final overflow = onCam.length > maxTiles;
        final shown = overflow ? onCam.take(maxTiles - 1).toList() : onCam;
        final hidden = overflow
            ? onCam.skip(maxTiles - 1).toList()
            : const <RoomParticipant>[];
        final count = shown.length + (overflow ? 1 : 0);
        final layout = stageLayout(
          count,
          Size(box.maxWidth - 8, box.maxHeight - 8),
          gap: 4,
        );
        return Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              for (var i = 0; i < count; i++)
                AnimatedPositioned.fromRect(
                  key: ValueKey(
                    i < shown.length ? 'pos-${shown[i].user.uuid}' : 'pos-more',
                  ),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  rect: layout.tiles[i],
                  child: i < shown.length
                      ? tile(
                          shown[i],
                          compact: i >= layout.featuredCount && count > 3,
                        )
                      : _MoreTile(people: hidden, onTap: onOverflow),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _VideoTopBar extends StatelessWidget {
  final String title;
  final bool premium;
  final bool speakerOn;
  final bool canFlipCamera;
  final VoidCallback onBack;
  final VoidCallback onFlipCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onTitle;
  final VoidCallback onLeave;
  final String leaveLabel;

  const _VideoTopBar({
    required this.title,
    required this.premium,
    required this.speakerOn,
    required this.canFlipCamera,
    required this.onBack,
    required this.onFlipCamera,
    required this.onToggleSpeaker,
    required this.onTitle,
    required this.onLeave,
    required this.leaveLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: Colors.white,
          ),
          if (canFlipCamera)
            IconButton(
              onPressed: onFlipCamera,
              icon: const Icon(Icons.flip_camera_ios_outlined, size: 22),
              color: Colors.white,
              tooltip: 'Flip camera',
            ),
          IconButton(
            onPressed: onToggleSpeaker,
            icon: Icon(
              speakerOn ? Icons.volume_up_outlined : Icons.volume_off_outlined,
              size: 22,
            ),
            color: Colors.white,
            tooltip: speakerOn ? 'Speaker on' : 'Speaker off',
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTitle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => MoonColors.dusk.createShader(r),
                    child: Icon(
                      premium
                          ? Icons.workspace_premium_rounded
                          : Icons.nightlight_round,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onLeave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: MoonColors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                leaveLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoTileView extends StatelessWidget {
  final RoomParticipant p;
  final String label;
  final bool speaking;
  final bool muted;
  final bool locked;
  final Widget? video;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onUnlock;

  const VideoTileView({
    super.key,
    required this.p,
    required this.label,
    required this.speaking,
    required this.muted,
    required this.locked,
    required this.video,
    required this.onTap,
    required this.onUnlock,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (locked) {
      body = _LockedBody(user: p.user, onUnlock: onUnlock);
    } else if (video != null) {
      body = video!;
    } else {
      body = _CameraOffBody(user: p.user);
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: MoonColors.tile),
            body,
            // Soft fade so the name chip always reads.
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0x99000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: _NameChip(
                  label: label,
                  speaking: speaking,
                  muted: muted,
                  compact: compact,
                ),
              ),
            ),
            if (p.user.isHost && !compact)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: MoonColors.dusk,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.nightlight_round,
                        color: Colors.white,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'HOST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (p.videoPremium && !locked)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: MoonColors.gold,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NameChip extends StatelessWidget {
  final String label;
  final bool speaking;
  final bool muted;
  final bool compact;

  const _NameChip({
    required this.label,
    required this.speaking,
    required this.muted,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xB3100E26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (muted)
            Icon(
              Icons.mic_off_rounded,
              color: const Color(0xFFFF6B81),
              size: compact ? 13 : 15,
            )
          else
            SoundWave(active: speaking, height: compact ? 11 : 13),
          SizedBox(width: compact ? 5 : 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 11 : 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraOffBody extends StatelessWidget {
  final RoomUser user;
  const _CameraOffBody({required this.user});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = (box.biggest.shortestSide * 0.42).clamp(32.0, 110.0);
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              MoonColors.nameColor(user.uuid).withValues(alpha: 0.28),
              MoonColors.tile,
            ],
            radius: 0.9,
          ),
        ),
        child: Center(child: MoonAvatar(user, size: size)),
      );
    },
  );
}

class _LockedBody extends StatelessWidget {
  final RoomUser user;
  final VoidCallback onUnlock;
  const _LockedBody({required this.user, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: _CameraOffBody(user: user),
        ),
        Container(color: Colors.black.withValues(alpha: 0.35)),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    color: MoonColors.gold,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onUnlock,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [MoonColors.gold, MoonColors.ember],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Unlock premium',
                        style: TextStyle(
                          color: MoonColors.night,
                          fontWeight: FontWeight.w800,
                        ),
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

class _MoreTile extends StatelessWidget {
  final List<RoomParticipant> people;
  final VoidCallback onTap;
  const _MoreTile({required this.people, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final faces = people.take(3).toList();
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: MoonColors.tile,
          child: LayoutBuilder(
            builder: (context, box) {
              final d = (box.biggest.shortestSide * 0.3).clamp(28.0, 64.0);
              Widget bubble(Widget child) => Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: MoonColors.tile, width: 2),
                ),
                child: child,
              );
              final items = <Widget>[
                for (final p in faces) bubble(MoonAvatar(p.user, size: d)),
                bubble(
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: MoonColors.dusk,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+${people.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: d * 0.34,
                      ),
                    ),
                  ),
                ),
              ];
              return Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SizedBox(
                      width: d * 2 + 6,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: items,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VideoToolbar extends StatelessWidget {
  final List<VideoToolItem> tools;
  const _VideoToolbar({required this.tools});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MoonColors.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = math.max(
                64.0,
                box.maxWidth / math.min(tools.length, 6),
              );
              return ListView(
                scrollDirection: Axis.horizontal,
                physics: tools.length * w > box.maxWidth
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                children: [
                  for (final t in tools)
                    SizedBox(
                      width: w,
                      child: _ToolButton(item: t),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final VideoToolItem item;
  const _ToolButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      item.icon,
      size: 24,
      color: item.highlighted ? Colors.white : Colors.white,
    );
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: item.highlighted
                ? BoxDecoration(
                    gradient: MoonColors.dusk,
                    borderRadius: BorderRadius.circular(14),
                  )
                : null,
            child: item.badge > 0
                ? Badge(
                    label: Text('${item.badge}'),
                    backgroundColor: MoonColors.danger,
                    child: icon,
                  )
                : icon,
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
