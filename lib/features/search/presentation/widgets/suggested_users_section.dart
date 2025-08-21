import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';

class SuggestedUsersSection extends StatelessWidget {
  final List<UserResult> users;
  final ValueChanged<UserResult> onFollow;

  const SuggestedUsersSection({
    super.key,
    required this.users,
    required this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested Users',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...users.map((user) => _buildUserTile(user)).toList(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUserTile(UserResult user) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.dark.withOpacity(0.3),
        child: user.avatarUrl != null
            ? ClipOval(child: Image.network(user.avatarUrl!))
            : const Icon(Icons.person, color: AppColors.textWhite),
      ),
      title: Text(
        user.name,
        style: const TextStyle(
          color: AppColors.textWhite,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '@${user.username}',
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: ElevatedButton(
        onPressed: () => onFollow(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.textWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('Follow'),
      ),
    );
  }
}
