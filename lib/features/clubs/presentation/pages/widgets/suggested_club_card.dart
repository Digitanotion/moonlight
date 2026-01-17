import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/domain/entities/suggested_club.dart';

class SuggestedClubCard extends StatelessWidget {
  final SuggestedClub club;
  final bool joined;
  final VoidCallback onJoin;

  const SuggestedClubCard({
    super.key,
    required this.club,
    required this.joined,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270, // ✅ REQUIRED for horizontal list
      height: 96,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ───────── Avatar (tappable → Club Profile) ─────────
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                RouteNames.clubProfile,
                arguments: {'clubUuid': club.uuid},
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white10,
                image: club.coverImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(club.coverImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: club.coverImageUrl == null
                  ? const Icon(Icons.groups, color: Colors.white54)
                  : null,
            ),
          ),

          const SizedBox(width: 14),

          // ───────── Text block (NO Expanded) ─────────
          SizedBox(
            width: 120, // 👈 Controls layout exactly like screenshot
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${club.membersCount} members',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    club.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ───────── Join button ─────────
          GestureDetector(
            onTap: joined ? null : onJoin,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: joined ? Colors.white24 : AppColors.accentGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                joined ? 'Joined' : 'Join',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: joined ? Colors.white70 : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
