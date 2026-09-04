// lib/features/home/presentation/widgets/live_tile_grid.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';
import 'package:moonlight/features/home/presentation/widgets/shimmer.dart';
import 'package:moonlight/widgets/image_placeholder.dart';
import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
import 'package:moonlight/widgets/top_snack.dart';
import '../../../../core/injection_container.dart';
import '../../../../features/live_viewer/presentation/pages/live_viewer_pager.dart'
    as pager_show;

class LiveTileGrid extends StatefulWidget {
  final LiveItem item;
  final List<LiveItem>? items;
  final int? index;

  const LiveTileGrid({super.key, required this.item, this.items, this.index});

  @override
  State<LiveTileGrid> createState() => _LiveTileGridState();
}

class _LiveTileGridState extends State<LiveTileGrid>
    with SingleTickerProviderStateMixin {
  bool _isChecking = false;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    // A quiet cascade-in rather than every tile popping at once — staggered
    // by the tile's position in the grid, capped so a long list doesn't
    // leave the last row waiting.
    final stagger = ((widget.index ?? 0) % 10) * 40;
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    Future.delayed(Duration(milliseconds: stagger), () {
      if (mounted) _enter.forward();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isChecking) return; // prevent double-tap

    setState(() => _isChecking = true);

    final navigator = Navigator.of(context);

    try {
      // Best-effort pre-check. If it returns a definitive non-live status we
      // tell the user and stop; but a rate-limit / timeout / transient error
      // must NOT block entry — the viewer screen runs its own health poll and
      // will surface the real state within a tick or two.
      try {
        final repo = sl<LiveFeedRepository>();
        final result = await repo
            .checkStreamStatus(liveId: widget.item.id ?? 0)
            .timeout(const Duration(seconds: 4));
        final status = result['status'] as String? ?? 'online';
        final message =
            result['message'] as String? ?? 'Stream is not available';

        if (!mounted) return;
        if (status != 'online' && status != 'pending') {
          TopSnack.info(context, message);
          return;
        }
      } catch (_) {
        // fall through and navigate anyway
      }

      if (!mounted) return;

      // ✅ Enter the stream
      final args = {
        'id': widget.item.id,
        'uuid': widget.item.uuid,
        'channel': widget.item.channel ?? '',
        'hostUuid': widget.item.hostUuid,
        'hostName': (widget.item.handle ?? '').replaceFirst('@', ''),
        'hostAvatar': widget.item.coverUrl ?? widget.item.hostAvatarUrl,
        'title': widget.item.title,
        'startedAt': widget.item.startedAt,
        'role': widget.item.role,
        'isPremium': widget.item.isPremium ?? 0,
        'premiumFee': widget.item.premiumFee ?? 0,
        'livestreamId': widget.item.uuid,
        'livestreamIdNumeric': widget.item.id,
      };

      if (widget.items != null && widget.index != null) {
        final allArgs = List<Map<String, dynamic>>.generate(
          widget.items!.length,
          (i) {
            final currentItem = widget.items![i];
            return {
              'id': currentItem.id,
              'uuid': currentItem.uuid,
              'channel': currentItem.channel ?? '',
              'hostUuid': currentItem.hostUuid,
              'hostName': (currentItem.handle ?? '').replaceFirst('@', ''),
              'hostAvatar': currentItem.coverUrl ?? currentItem.hostAvatarUrl,
              'title': currentItem.title,
              'startedAt': currentItem.startedAt,
              'role': currentItem.role,
              'isPremium': currentItem.isPremium ?? 0,
              'premiumFee': currentItem.premiumFee ?? 0,
              'livestreamId': currentItem.uuid,
              'livestreamIdNumeric': currentItem.id,
            };
          },
        );

        if (!mounted) return;
        navigator.push(
          pager_show.LiveViewerPager.route(
            items: widget.items!,
            initialIndex: widget.index!,
            allArgs: allArgs,
          ),
        );
        return;
      }

      if (!mounted) return;
      navigator.pushNamed(RouteNames.liveViewer, arguments: args);
    } catch (e) {
      if (!mounted) return;
      TopSnack.error(
        context,
        'Could not verify stream status. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flag = isoToFlagEmoji(widget.item.countryIso2 ?? '');
    final countryName = widget.item.countryName ?? '';
    final name = (widget.item.handle ?? '').replaceFirst('@', '');

    return AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_enter.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.94 + (0.06 * t),
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _handleTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Background: cover → host avatar → initials ────────
                _LiveTileBackground(
                  coverUrl: widget.item.coverUrl,
                  avatarUrl: widget.item.hostAvatarUrl,
                  name: name,
                ),

                // ── Flat gradient scrim (just enough for text legibility) ─
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xB3000000), Color(0x00000000)],
                        stops: [0.0, 0.65],
                      ),
                    ),
                  ),
                ),

                // ── Loading overlay (shown while checking status) ─────
                if (_isChecking)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _isChecking ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        color: Colors.black.withOpacity(0.55),
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Top row: LIVE pulse + viewer count ────────────────
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      const _LivePulsePill(),
                      const Spacer(),
                      _GlassPill(
                        icon: Icons.remove_red_eye_rounded,
                        label: formatCompact(widget.item.viewers),
                      ),
                    ],
                  ),
                ),

                // ── Bottom: avatar chip + name, one compact meta line ──
                Positioned(
                  left: 9,
                  right: 9,
                  bottom: 9,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _MiniAvatar(
                        url: widget.item.coverUrl ?? widget.item.hostAvatarUrl,
                        name: name,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name.isEmpty ? 'host' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                height: 1.1,
                              ),
                            ),
                            if (countryName.isNotEmpty || flag.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  [
                                    if (flag.isNotEmpty) flag,
                                    if (countryName.isNotEmpty) countryName,
                                  ].join(' '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
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

/// Cover image → host avatar → initials tile, in that order. Whichever wins,
/// it fills the whole card.
class _LiveTileBackground extends StatelessWidget {
  final String? coverUrl;
  final String? avatarUrl;
  final String name;

  const _LiveTileBackground({
    required this.coverUrl,
    required this.avatarUrl,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final cover = coverUrl?.trim();
    final avatar = avatarUrl?.trim();
    final imageUrl = (cover != null && cover.isNotEmpty)
        ? cover
        : (avatar != null && avatar.isNotEmpty ? avatar : null);

    if (imageUrl != null) {
      return NetworkImageWithPlaceholder(
        url: imageUrl,
        fit: BoxFit.cover,
        shimmer: true,
        icon: Icons.videocam_rounded,
      );
    }
    return _InitialsTile(name: name);
  }
}

/// No cover, no avatar — a flat gradient tile carrying the host's initial,
/// coloured deterministically from their name (same trick as WhatsApp/
/// Telegram contact avatars, so the same host always gets the same colour).
/// A slow light sweep keeps it from feeling like a dead/broken image.
class _InitialsTile extends StatelessWidget {
  final String name;
  const _InitialsTile({required this.name});

  static const _palettes = [
    [Color(0xFF6B5BFF), Color(0xFF2E1F6B)],
    [Color(0xFFFF6A88), Color(0xFF6A1F4A)],
    [Color(0xFFFFA43D), Color(0xFF6B3A0E)],
    [Color(0xFF35D0BA), Color(0xFF0E4A46)],
    [Color(0xFF4C8DFF), Color(0xFF10245C)],
    [Color(0xFFE0526B), Color(0xFF4A0E22)],
    [Color(0xFF9B5CFF), Color(0xFF2A0E5C)],
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
    final hash = trimmed.isEmpty
        ? 0
        : trimmed.codeUnits.fold<int>(0, (a, b) => a + b);
    final colors = _palettes[hash % _palettes.length];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Shimmer(
          period: const Duration(milliseconds: 2600),
          child: Text(
            letter,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 46,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular avatar chip for the bottom-left credit — same
/// image → initials fallback as the card background, independent of it (the
/// card can be showing the avatar full-bleed while this stays a neat chip).
class _MiniAvatar extends StatelessWidget {
  final String? url;
  final String name;
  const _MiniAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final u = url?.trim();
    final has = u != null && u.isNotEmpty;
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1),
        color: const Color(0xFF2A2A3A),
      ),
      clipBehavior: Clip.antiAlias,
      child: has
          ? NetworkImageWithPlaceholder(
              url: u,
              fit: BoxFit.cover,
              shimmer: false,
            )
          : Center(
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}

/// A breathing red dot + "LIVE" — flatter and quieter than a solid red
/// block, closer to how TikTok/Tango mark a live tile.
class _LivePulsePill extends StatefulWidget {
  const _LivePulsePill();

  @override
  State<_LivePulsePill> createState() => _LivePulsePillState();
}

class _LivePulsePillState extends State<_LivePulsePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPill(
      color: Colors.black.withOpacity(0.38),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = 0.55 + (0.45 * (1 - (_c.value - 0.5).abs() * 2));
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    const Color(0xFFFF3B3B),
                    const Color(0xFFFF7A7A),
                    v,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B3B).withOpacity(0.55 * v),
                      blurRadius: 5 * v,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared frosted-glass pill chrome for the top-row badges.
class _GlassPill extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final Color? color;
  final Widget? child;

  const _GlassPill({this.icon, this.label, this.color, this.child})
    : assert(child != null || (icon != null && label != null));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Colors.black.withOpacity(0.32),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child:
          child ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
    );
  }
}
