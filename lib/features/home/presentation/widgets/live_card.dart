import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';
import 'package:moonlight/widgets/image_placeholder.dart';

class LiveCardVertical extends StatelessWidget {
  final LiveItem item;
  const LiveCardVertical({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final flag = isoToFlagEmoji(item.countryIso2 ?? '');
    final countryName = item.countryName ?? 'Unknown';
    final viewersText = formatCompact(item.viewers);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).pushNamed(
          RouteNames.liveViewer,
          arguments: {
            'id': item.id, // ✅ numeric id for Pusher channels
            'uuid': item.uuid, // ✅ REST accepts uuid or numeric
            'channel': item.channel,
            'hostName': item.handle.replaceFirst('@', ''),
            'hostAvatar': item.coverUrl, // if you have it
            'title': item.title, // if you have it
            'startedAt': item.startedAt, // ISO8601 if present
            'role': item.role,
          },
        );
      },
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.02),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Thumbnail (cover_url)
              Positioned.fill(
                child: NetworkImageWithPlaceholder(
                  url: item.coverUrl,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(16),
                  shimmer: true,
                  icon: Icons.videocam_rounded,
                ),
              ),
              // Overlay gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.15),
                      ],
                    ),
                  ),
                ),
              ),

              // LIVE + viewers (top)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'LIVE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.remove_red_eye_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            viewersText,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom details: @user_slug, role, Flag + Country
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // @user_slug
                    Text(
                      item.handle, // already "@user_slug"
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // role
                    Text(
                      item.role,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Flag + Country
                    Row(
                      children: [
                        Text(flag, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          countryName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
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
