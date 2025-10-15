import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import '../../../../core/theme/app_colors.dart';

class RolePill extends StatelessWidget {
  final String text;
  final Color color;
  const RolePill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.6), width: 1),
      ),
      child: Text(text, style: AppTextStyles.small.copyWith(color: color)),
    );
  }
}

class TagChip extends StatelessWidget {
  final String text;
  const TagChip({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppColors.hashtag.withOpacity(0.12),
        border: Border.all(color: AppColors.hashtag),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '#$text',
        style: AppTextStyles.small.copyWith(color: AppColors.onSurface),
      ),
    );
  }
}
