import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';

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

  String get _previewUrl {
    // Prefer thumb for videos; else mediaUrl. For images, mediaUrl is fine.
    return post.thumbUrl?.isNotEmpty == true ? post.thumbUrl! : post.mediaUrl;
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
    final timeAgo = DateFormat.MMMd().add_Hm().format(post.createdAt.toLocal());
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
                  timeAgo,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Media (image or video preview)
          GestureDetector(
            onTap: onOpenPost,
            child: Hero(
              tag: 'post_${post.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Preview image (thumb for video, or image itself)
                      CachedNetworkImage(
                        imageUrl: _previewUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        fadeInDuration: const Duration(milliseconds: 160),
                        placeholder: (c, _) => Container(color: Colors.white12),
                        errorWidget: (c, _, __) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                          ),
                        ),
                      ),

                      if (_isVideo) ...[
                        // gradient scrim for better contrast
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black54, Colors.transparent],
                            ),
                          ),
                        ),
                        // centered play icon
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 58,
                            color: Colors.white,
                          ),
                        ),
                        // subtle "Video" chip (bottom-left)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.videocam_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Video',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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

          // Metrics (like, comment, views) – NO share here
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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.9,
    upperBound: 1.0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isLiked ? const Color(0xFFFF4D67) : Colors.white70;
    return GestureDetector(
      onTap: () async {
        await _c.forward(from: 0.9);
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _c.drive(Tween(begin: 1.0, end: 1.0)),
        child: Row(
          children: [
            Icon(
              widget.isLiked ? Icons.favorite : Icons.favorite_border,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.count}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
