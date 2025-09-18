import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';
import 'package:moonlight/widgets/image_placeholder.dart';

class LiveTileGrid extends StatelessWidget {
  final LiveItem item;
  const LiveTileGrid({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final flag = isoToFlagEmoji(item.countryIso2 ?? '');
    final countryName = item.countryName ?? 'Unknown';

    Widget _image() {
      final placeholder = Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.cover,
      );
      final url = item.coverUrl;
      if (url == null || url.trim().isEmpty) return placeholder;

      // Fade-in + error fallback
      return FadeInImage.assetNetwork(
        placeholder: 'assets/images/logo.png',
        image: url,
        fit: BoxFit.cover,
        imageErrorBuilder: (_, __, ___) => placeholder,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).pushNamed(
          RouteNames.liveViewer,
          arguments: {
            'id': item.id, // REQUIRED numeric for Pusher
            'uuid': item.uuid, // REST path (uuid or numeric ok)
            'channel': item.channel, // e.g. "live_zNt4yMaaQwhf"
            'hostName': item.handle.replaceFirst('@', ''),
            'hostAvatar': item.coverUrl,
            'title': item.title,
            'startedAt': item.startedAt,
            'role': item.role,
          },
        );
      },
      child: Container(
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
              Positioned.fill(
                child: NetworkImageWithPlaceholder(
                  url: item.coverUrl, // cover_url from API (may be null)
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(16),
                  shimmer: true, // nice social-style loading
                  icon: Icons.videocam_rounded, // or any icon you prefer
                  iconSize: 44,
                  // gradient: [Color(0xFF303030), Color(0xFF1A1A1A)], // optional customization
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.60),
                        Colors.black.withOpacity(0.15),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
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
                            formatCompact(item.viewers),
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
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.role,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(flag, style: const TextStyle(fontSize: 14)),
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
