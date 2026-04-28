// lib/features/home/presentation/widgets/live_tile_grid.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';
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

class _LiveTileGridState extends State<LiveTileGrid> {
  bool _isChecking = false;

  Future<void> _handleTap() async {
    if (_isChecking) return; // prevent double-tap

    setState(() => _isChecking = true);

    final navigator = Navigator.of(context);

    try {
      final repo = sl<LiveFeedRepository>();
      final result = await repo.checkStreamStatus(liveId: widget.item.id ?? 0);
      final status = result['status'] as String? ?? 'offline';
      final message = result['message'] as String? ?? 'Stream is not available';

      if (!mounted) return;

      if (status != 'online') {
        TopSnack.info(context, message);
        return;
      }

      // ✅ Stream is online — navigate
      final args = {
        'id': widget.item.id,
        'uuid': widget.item.uuid,
        'channel': widget.item.channel ?? '',
        'hostUuid': widget.item.hostUuid,
        'hostName': (widget.item.handle ?? '').replaceFirst('@', ''),
        'hostAvatar': widget.item.coverUrl,
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
              'hostAvatar': currentItem.coverUrl,
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
          MaterialPageRoute(
            builder: (_) => pager_show.LiveViewerPager(
              items: widget.items!,
              initialIndex: widget.index!,
              allArgs: allArgs,
            ),
            fullscreenDialog: true,
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
    final countryName = widget.item.countryName ?? 'Unknown';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _handleTap,
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
              // ── Background image ──────────────────────────────────
              Positioned.fill(
                child: NetworkImageWithPlaceholder(
                  url: widget.item.coverUrl,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(16),
                  shimmer: true,
                  icon: Icons.videocam_rounded,
                  iconSize: 44,
                ),
              ),

              // ── Dark gradient overlay ─────────────────────────────
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

              // ── Loading overlay (shown while checking status) ─────
              if (_isChecking)
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _isChecking ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Checking stream...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Top row: LIVE badge + viewer count ────────────────
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
                            formatCompact(widget.item.viewers),
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

              // ── Bottom info ───────────────────────────────────────
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.handle ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item.role ?? '',
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
