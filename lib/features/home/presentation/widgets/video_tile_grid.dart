// lib/features/home/presentation/widgets/video_tile_grid.dart
//
// The video counterpart to LiveTileGrid, styled to match exactly (same
// flat dark card, same radius/border/shadow) so lives and videos "sit
// together as one" grid, per spec. Deliberately carries NO live badge —
// that's reserved for LiveTileGrid only.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:moonlight/widgets/video_thumbnail.dart';

class VideoTileGrid extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const VideoTileGrid({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: const Color(0xFF0C0C12),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Thumbnail(post: post),

                // Bottom gradient scrim so the overlays below stay readable
                // over any thumbnail.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ),

                // Author credit, bottom-left — small avatar + name.
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Row(
                    children: [
                      _MiniAvatar(url: post.author.avatarUrl),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          post.author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // View count, top-right.
                Positioned(
                  top: 8,
                  right: 8,
                  child: _ViewsChip(views: post.views),
                ),

                // Country flag, top-left — lets the country filter's effect
                // (Watch tab, videos included now) be visually verified on
                // each card, same idea as the live tiles' own country cue.
                if (post.author.countryFlagEmoji.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        post.author.countryFlagEmoji,
                        style: const TextStyle(fontSize: 12),
                      ),
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

class _Thumbnail extends StatelessWidget {
  final Post post;
  const _Thumbnail({required this.post});

  @override
  Widget build(BuildContext context) {
    final url = post.thumbUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _generated(),
        placeholder: (_, _) => Container(color: const Color(0xFF1A1A2E)),
      );
    }
    // No server-generated thumbnail — extract a real frame from the video
    // client-side. Same widget/package already used for this exact job on
    // feed_post_card's video cards and chat video messages, so this gets
    // its on-disk cache for free rather than re-decoding every rebuild.
    return _generated();
  }

  Widget _generated() {
    return LayoutBuilder(
      builder: (context, constraints) => VideoThumbnailWidget(
        videoUrl: post.mediaUrl,
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String url;
  const _MiniAvatar({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: ClipOval(
        child: url.isEmpty
            ? Container(color: const Color(0xFF2A2A3A))
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    Container(color: const Color(0xFF2A2A3A)),
              ),
      ),
    );
  }
}

class _ViewsChip extends StatelessWidget {
  final int views;
  const _ViewsChip({required this.views});

  String get _label {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return '$views';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.play_circle_outline_rounded,
            color: Colors.white70,
            size: 11,
          ),
          const SizedBox(width: 3),
          Text(
            _label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
