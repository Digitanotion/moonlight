// lib/features/live_viewer/presentation/widgets/live_loading_placeholder.dart
//
// Shown while the Agora channel is being joined.
// Replicates the TikTok/Tango pattern:
//   • Host cover image fills the screen, blurred
//   • Circular avatar centred, sharp
//   • Pulsing glow ring to signal "loading with life"
//   • Smooth fade-out once video is ready (caller drives the opacity)

import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class LiveLoadingPlaceholder extends StatefulWidget {
  /// URL of the host's cover / avatar image (from LiveItem.coverUrl).
  final String? avatarUrl;

  /// Host display name — shown below the avatar.
  final String? hostName;

  /// 0.0 → fully visible placeholder, 1.0 → fully transparent (video showing).
  /// Animate this from 0→1 in the parent once video is ready.
  final double fadeOutProgress;

  const LiveLoadingPlaceholder({
    super.key,
    this.avatarUrl,
    this.hostName,
    this.fadeOutProgress = 0.0,
  });

  @override
  State<LiveLoadingPlaceholder> createState() => _LiveLoadingPlaceholderState();
}

class _LiveLoadingPlaceholderState extends State<LiveLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _ringScale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _glowOpacity = Tween<double>(
      begin: 0.25,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    _ringScale = Tween<double>(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fade the whole placeholder out as video comes in
    final visible = 1.0 - widget.fadeOutProgress.clamp(0.0, 1.0);

    return Opacity(
      opacity: visible,
      // Don't absorb taps once fading out
      child: IgnorePointer(
        ignoring: visible < 0.05,
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Blurred background ──────────────────────────────────────
              _BlurredBackground(url: widget.avatarUrl),

              // ── Dark scrim so avatar pops ───────────────────────────────
              Container(color: Colors.black.withOpacity(0.45)),

              // ── Centre: pulsing ring + avatar ───────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) => Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          Transform.scale(
                            scale: _ringScale.value,
                            child: Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(
                                      _glowOpacity.value,
                                    ),
                                    blurRadius: 28,
                                    spreadRadius: 6,
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.orange.withOpacity(
                                    _glowOpacity.value,
                                  ),
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                          // Avatar
                          child!,
                        ],
                      ),
                      child: _HostAvatar(url: widget.avatarUrl, size: 96),
                    ),

                    const SizedBox(height: 16),

                    // Host name
                    if (widget.hostName != null &&
                        widget.hostName!.isNotEmpty) ...[
                      Text(
                        widget.hostName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // "Joining stream…" text
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Opacity(
                        opacity: _glowOpacity.value,
                        child: const Text(
                          'Joining stream…',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
      ),
    );
  }
}

// ── Blurred background ────────────────────────────────────────────────────────

class _BlurredBackground extends StatelessWidget {
  final String? url;
  const _BlurredBackground({this.url});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark fallback
        Container(color: const Color(0xFF0A0A1A)),

        if (url != null && url!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),

        // Blur overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

// ── Circular avatar ───────────────────────────────────────────────────────────

class _HostAvatar extends StatelessWidget {
  final String? url;
  final double size;
  const _HostAvatar({this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              placeholder: (_, __) => _fallback(),
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => Container(
    color: const Color(0xFF1A1040),
    child: const Icon(Icons.person, color: Colors.white54, size: 40),
  );
}
