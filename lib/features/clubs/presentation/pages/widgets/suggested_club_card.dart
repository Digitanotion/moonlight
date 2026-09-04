import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/domain/entities/suggested_club.dart';

/// A tall, image-led card for the "Suggested" carousel on the Discover screen.
///
/// Cover art with a bottom scrim, the club name and member count laid over it,
/// a frosted "reason" chip top-right, and a single Join / Joined action.
class SuggestedClubCard extends StatelessWidget {
  final SuggestedClub club;
  final bool joined;
  final bool joining;
  final VoidCallback onJoin;

  const SuggestedClubCard({
    super.key,
    required this.club,
    required this.joined,
    required this.onJoin,
    this.joining = false,
  });

  static const double width = 244;
  static const double height = 176;

  void _openProfile(BuildContext context) {
    Navigator.pushNamed(
      context,
      RouteNames.clubProfile,
      arguments: {'clubUuid': club.uuid},
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = (club.coverImageUrl ?? '').startsWith('http');

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: AppColors.card,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Cover ───────────────────────────────────────────────
            if (hasCover)
              CachedNetworkImage(
                imageUrl: club.coverImageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const _CoverFallback(),
                placeholder: (_, _) => const _CoverFallback(),
              )
            else
              const _CoverFallback(),

            // ── Scrim ───────────────────────────────────────────────
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x33000914),
                    Color(0xF2050A1E),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // ── Card tap (ripple sits over the cover) ───────────────
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => _openProfile(context),
                  splashColor: Colors.white.withOpacity(0.12),
                  highlightColor: Colors.white.withOpacity(0.04),
                ),
              ),
            ),

            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
              ),
            ),

            // ── Reason chip ─────────────────────────────────────────
            if (club.reason.trim().isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                child: IgnorePointer(
                  child: _FrostedChip(label: club.reason.trim()),
                ),
              ),

            // ── Text + action ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        size: 13,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _members(club.membersCount),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _JoinPill(
                    joined: joined,
                    joining: joining,
                    onTap: joined || joining ? null : onJoin,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _members(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M members';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K members';
    return '$n member${n == 1 ? '' : 's'}';
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2A6B), Color(0xFF0B1230)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.groups_2_rounded,
          size: 46,
          color: Colors.white.withOpacity(0.14),
        ),
      ),
    );
  }
}

class _FrostedChip extends StatelessWidget {
  final String label;
  const _FrostedChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinPill extends StatelessWidget {
  final bool joined;
  final bool joining;
  final VoidCallback? onTap;

  const _JoinPill({
    required this.joined,
    required this.joining,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: joined ? Colors.white.withOpacity(0.14) : AppColors.secondary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: joined
              ? null
              : [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: joining
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    joined ? Icons.check_rounded : Icons.add_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    joined ? 'Joined' : 'Join club',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
