// lib/features/home/presentation/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class PostCard extends StatelessWidget {
  final String avatarUrl;
  final String handle;
  final String badge; // e.g., "Ambassador 🥇", "Superstar 🥇"
  final String timeAgo; // e.g., "3h ago"
  final String imageUrl;
  final String caption;
  final String likes;
  final String comments;
  final String views;

  const PostCard({
    super.key,
    required this.avatarUrl,
    required this.handle,
    required this.badge,
    required this.timeAgo,
    required this.imageUrl,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.views,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 14),
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
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(avatarUrl),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        handle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        badge,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
          // Media
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
              bottom: Radius.circular(0),
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              height: 180,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          // Caption
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                caption,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textWhite,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Metrics row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 10, 12),
            child: Row(
              children: [
                _Metric(icon: Icons.favorite_border, label: likes),
                const SizedBox(width: 14),
                _Metric(icon: Icons.mode_comment_outlined, label: comments),
                const SizedBox(width: 14),
                _Metric(icon: Icons.visibility_outlined, label: views),
                const Spacer(),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.ios_share,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
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
  const _Metric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
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
  }
}
