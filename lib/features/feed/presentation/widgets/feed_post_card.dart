import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/utils/time_ago.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// ── Design tokens (shared with feed_screen.dart) ──────────────────────────
class _C {
  static const surface = Color(0xFF0E1024);
  static const border = Color(0xFF1A1D3D);
  static const accent = Color(0xFFFF6A00);
  static const textSecondary = Color(0xFF8B8FB8);
}

class FeedPostCard extends StatelessWidget {
  const FeedPostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onOpenPost,
    required this.onOpenProfile,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onOpenPost;
  final VoidCallback onOpenProfile;

  bool get _isVideo {
    final t = post.mediaType?.toLowerCase() ?? '';
    if (t.startsWith('video/')) return true;
    final u = post.mediaUrl.toLowerCase();
    return u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.mkv') ||
        u.endsWith('.webm');
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  Widget _buildAvatar() {
    final avatar = post.author.avatarUrl;
    final valid = _isValidUrl(avatar);
    if (!valid) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _C.accent.withOpacity(0.16),
          border: Border.all(color: _C.accent.withOpacity(0.3)),
        ),
        child: const Icon(
          Icons.person_rounded,
          color: Colors.white70,
          size: 20,
        ),
      );
    }
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _C.border, width: 1.5),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatar,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) =>
              const Icon(Icons.person_rounded, color: Colors.white38),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badge = post.author.roleLabel.isNotEmpty
        ? post.author.roleLabel
        : 'Member';

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                GestureDetector(onTap: onOpenProfile, child: _buildAvatar()),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onOpenProfile,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _RolePill(label: badge),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeAgoFrom(post.createdAt),
                  style: TextStyle(
                    color: _C.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ── Media — edge-to-edge, no horizontal margin ──────────────────
          GestureDetector(
            onTap: onOpenPost,
            child: Hero(
              tag: 'post_${post.id}',
              child: AspectRatio(
                aspectRatio: 16 / 11,
                child: _isVideo
                    ? _VideoThumbnailWidget(
                        videoUrl: post.mediaUrl,
                        serverThumbUrl: post.thumbUrl,
                      )
                    : _ImageWidget(url: post.mediaUrl),
              ),
            ),
          ),

          // ── Caption ──────────────────────────────────────────────────────
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text(
                post.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

          // ── Metrics — single quiet row ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 12),
            child: Row(
              children: [
                _LikeMetric(
                  isLiked: post.isLiked,
                  count: post.likes,
                  onTap: onOpenPost, // ← tapping heart opens post, not likes it
                ),
                const SizedBox(width: 18),
                _Metric(
                  icon: Icons.mode_comment_rounded,
                  label: '${post.commentsCount}',
                  onTap: onOpenPost,
                ),
                const SizedBox(width: 18),
                _Metric(icon: Icons.visibility_rounded, label: '${post.views}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Role pill — small caps, accent-tinted, not a plain text label ─────────
class _RolePill extends StatelessWidget {
  final String label;
  const _RolePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _C.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: _C.accent,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Image widget ────────────────────────────────────────────────────────
class _ImageWidget extends StatelessWidget {
  final String url;
  const _ImageWidget({required this.url});

  bool get _valid {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid) {
      return Container(
        color: _C.border,
        child: const Center(
          child: Icon(Icons.image_rounded, color: Colors.white24, size: 36),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) => Container(color: _C.border),
      errorWidget: (_, __, ___) => Container(
        color: _C.border,
        child: const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white24),
        ),
      ),
    );
  }
}

// ── Video thumbnail widget ───────────────────────────────────────────────
// Priority: 1) serverThumbUrl  2) on-device generation  3) placeholder
class _VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  final String? serverThumbUrl;

  const _VideoThumbnailWidget({required this.videoUrl, this.serverThumbUrl});

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget>
    with SingleTickerProviderStateMixin {
  File? _localThumb;
  bool _generating = false;
  bool _failed = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  bool get _serverThumbValid {
    final url = widget.serverThumbUrl;
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  @override
  void initState() {
    super.initState();
    if (!_serverThumbValid) _generateThumbnail();
  }

  @override
  void didUpdateWidget(covariant _VideoThumbnailWidget old) {
    super.didUpdateWidget(old);
    if (old.videoUrl != widget.videoUrl && !_serverThumbValid) {
      setState(() {
        _localThumb = null;
        _failed = false;
      });
      _generateThumbnail();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _generateThumbnail() async {
    if (_generating || widget.videoUrl.isEmpty) return;
    _generating = true;
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheKey = widget.videoUrl.hashCode.abs();
      final cachePath = '${tempDir.path}/feed_thumb_$cacheKey.jpg';
      final cacheFile = File(cachePath);

      if (await cacheFile.exists()) {
        if (mounted) setState(() => _localThumb = cacheFile);
        return;
      }

      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        quality: 75,
        timeMs: 1000,
      );

      if (bytes != null && bytes.isNotEmpty) {
        await cacheFile.writeAsBytes(bytes);
        if (mounted) setState(() => _localThumb = cacheFile);
      } else {
        if (mounted) setState(() => _failed = true);
      }
    } catch (e) {
      debugPrint('FeedPostCard thumb gen failed: $e');
      if (mounted) setState(() => _failed = true);
    } finally {
      _generating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_serverThumbValid)
          CachedNetworkImage(
            imageUrl: widget.serverThumbUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            fadeInDuration: const Duration(milliseconds: 180),
            placeholder: (_, __) => _buildPlaceholder(loading: true),
            errorWidget: (_, __, ___) => _buildPlaceholder(loading: false),
          )
        else if (_localThumb != null)
          Image.file(
            _localThumb!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        else
          _buildPlaceholder(loading: !_failed),

        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
              stops: [0.0, 0.5],
            ),
          ),
        ),

        // ── Signature: soft pulsing ring around play icon ─────────────────
        Center(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final scale = 1.0 + (_pulse.value * 0.18);
              final opacity = 0.5 - (_pulse.value * 0.35);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(opacity),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black38,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_rounded, size: 12, color: Colors.white),
                SizedBox(width: 5),
                Text(
                  'Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder({required bool loading}) {
    return Container(
      color: _C.border,
      child: Center(
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _C.accent.withOpacity(0.7),
                ),
              )
            : const Icon(
                Icons.videocam_off_rounded,
                color: Colors.white24,
                size: 32,
              ),
      ),
    );
  }
}

// ── Metric widgets ───────────────────────────────────────────────────────
class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Metric({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _C.textSecondary, size: 17),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: _C.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: row,
      ),
    );
  }
}

// ── Like metric — signature particle-burst micro-interaction ─────────────
class _LikeMetric extends StatefulWidget {
  const _LikeMetric({
    required this.isLiked,
    required this.count,
    required this.onTap,
  });
  final bool isLiked;
  final int count;
  final VoidCallback onTap;

  @override
  State<_LikeMetric> createState() => _LikeMetricState();
}

class _LikeMetricState extends State<_LikeMetric>
    with TickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    lowerBound: 0.7,
    upperBound: 1.0,
    value: 1.0,
  );

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  static const _likedColor = _C.accent;

  @override
  void dispose() {
    _bounce.dispose();
    _burst.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final wasLiked = widget.isLiked;
    await _bounce.animateTo(
      0.7,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeIn,
    );
    await _bounce.animateTo(
      1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.elasticOut,
    );
    // Only burst when transitioning TO liked, not when unliking.
    if (!wasLiked) {
      _burst.forward(from: 0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isLiked ? _likedColor : _C.textSecondary;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: ScaleTransition(
          scale: _bounce,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: _burst,
                      builder: (context, _) => _ParticleBurst(
                        progress: _burst.value,
                        color: _likedColor,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        widget.isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey(widget.isLiked),
                        color: color,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                child: Text('${widget.count}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Particle burst — 6 dots radiating outward on like ─────────────────────
class _ParticleBurst extends StatelessWidget {
  final double progress; // 0.0 → 1.0
  final Color color;
  const _ParticleBurst({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return const SizedBox.shrink();

    const count = 6;
    final fadeOut = (1 - progress).clamp(0.0, 1.0);
    final distance = progress * 16;

    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(count, (i) {
          final angle = (i / count) * 2 * math.pi;
          final dx = math.cos(angle) * distance;
          final dy = math.sin(angle) * distance;
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Opacity(
              opacity: fadeOut,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ),
          );
        }),
      ),
    );
  }
}
