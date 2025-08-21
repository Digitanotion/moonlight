import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';

class PopularClubsSection extends StatelessWidget {
  final List<ClubResult> clubs;
  final ValueChanged<ClubResult> onJoin;

  const PopularClubsSection({
    super.key,
    required this.clubs,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    if (clubs.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clubs to Explore',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...clubs.map((club) => _buildClubTile(club)).toList(),
      ],
    );
  }

  Widget _buildClubTile(ClubResult club) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.dark.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: club.coverImageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(club.coverImageUrl!),
              )
            : const Icon(Icons.groups, color: AppColors.textWhite),
      ),
      title: Text(
        club.name,
        style: const TextStyle(
          color: AppColors.textWhite,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${club.membersCount.formatCount()} members',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: ElevatedButton(
        onPressed: () => onJoin(club),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('Join'),
      ),
    );
  }
}

extension FormatCount on int {
  String formatCount() {
    if (this >= 1000000) {
      return '${(this / 1000000).toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      return '${(this / 1000).toStringAsFixed(1)}k';
    }
    return toString();
  }
}
