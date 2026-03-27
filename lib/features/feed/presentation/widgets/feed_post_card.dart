import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/time_ago.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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
      return CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.primary.withOpacity(0.25),
        child: const Icon(Icons.person, color: Colors.white70),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundImage: CachedNetworkImageProvider(avatar),
      backgroundColor: AppColors.primary.withOpacity(0.06),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badge = post.author.roleLabel.isNotEmpty
        ? post.author.roleLabel
        : 'Member';

    return Container(
      margin: const EdgeInsets.fromLTRB(5, 8, 5, 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                GestureDetector(onTap: onOpenProfile, child: _buildAvatar()),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onOpenProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author.name,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          badge,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  timeAgoFrom(post.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Media
          GestureDetector(
            onTap: onOpenPost,
            child: Hero(
              tag: 'post_${post.id}',
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isVideo
                    ? _VideoThumbnailWidget(
                        videoUrl: post.mediaUrl,
                        serverThumbUrl: post.thumbUrl,
                      )
                    : _ImageWidget(url: post.mediaUrl),
              ),
            ),
          ),

          // Caption
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                post.caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textWhite,
                  height: 1.35,
                ),
              ),
            ),
          ),

          // Metrics
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Row(
              children: [
                _LikeMetric(
                  isLiked: post.isLiked,
                  count: post.likes,
                  onTap: onLike,
                ),
                const SizedBox(width: 16),
                _Metric(
                  icon: Icons.mode_comment_outlined,
                  label: '${post.commentsCount}',
                  onTap: onOpenPost,
                ),
                const SizedBox(width: 16),
                _Metric(
                  icon: Icons.visibility_outlined,
                  label: '${post.views}',
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Image widget
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
        color: Colors.white10,
        child: const Center(
          child: Icon(Icons.photo, color: Colors.white38, size: 40),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 160),
      placeholder: (_, __) => Container(color: Colors.white12),
      errorWidget: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image, color: Colors.white54)),
    );
  }
}

// Video thumbnail widget
// Priority: 1) serverThumbUrl  2) on-device generation  3) placeholder
class _VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  final String? serverThumbUrl;

  const _VideoThumbnailWidget({required this.videoUrl, this.serverThumbUrl});

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> {
  File? _localThumb;
  bool _generating = false;
  bool _failed = false;

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
        // Thumbnail layer
        if (_serverThumbValid)
          CachedNetworkImage(
            imageUrl: widget.serverThumbUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            fadeInDuration: const Duration(milliseconds: 160),
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

        // Video overlays
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
        ),
        const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            size: 58,
            color: Colors.white,
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.videocam_rounded, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Video',
                  style: TextStyle(color: Colors.white, fontSize: 12),
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
      color: Colors.white10,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              )
            : const Icon(
                Icons.videocam_outlined,
                color: Colors.white38,
                size: 40,
              ),
      ),
    );
  }
}

// Metric widgets
class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Metric({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    return onTap == null ? row : GestureDetector(onTap: onTap, child: row);
  }
}

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    lowerBound: 0.7,
    upperBound: 1.0,
    value: 1.0,
  );

  static const _likedColor = Color(0xFFFF4D67);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _ctrl.animateTo(
      0.7,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeIn,
    );
    await _ctrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.elasticOut,
    );
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isLiked ? _likedColor : Colors.white70;

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _ctrl,
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                widget.isLiked ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(widget.isLiked),
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              child: Text('${widget.count}'),
            ),
          ],
        ),
      ),
    );
  }
}
