import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';

class TrendingTagsSection extends StatelessWidget {
  final List<TagResult> tags;

  const TrendingTagsSection({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '#Trending Tags',
          style: AppTextStyles.heading2.copyWith(color: AppColors.textWhite),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tags.map((tag) => _buildTagChip(tag)).toList(),
        ),
      ],
    );
  }

  Widget _buildTagChip(TagResult tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dark.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tag.name,
        style: const TextStyle(
          color: AppColors.textWhite,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }
}
