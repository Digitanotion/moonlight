import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';

class EmptySearchState extends StatelessWidget {
  final String query;

  const EmptySearchState({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search query display
          Text(
            query,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.textWhite,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.textSecondary, height: 1),
          const SizedBox(height: 32),

          // No results found
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.search_off,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 24),
                Text(
                  'No Results Found',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We couldn\'t find anything matching $query.\nTry a different keyword or check your spelling.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // Try searching for section
                const Text(
                  'Try searching for:',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                // Hashtag suggestions
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildSuggestionChip('#AfroBeatLive'),
                    _buildSuggestionChip('#StudyClubs'),
                  ],
                ),
                const SizedBox(height: 24),

                // Browse options
                const Text(
                  'Browse Popular Clubs',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Explore Trending',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dark.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: AppColors.textWhite,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }
}
