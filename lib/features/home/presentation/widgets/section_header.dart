// lib/features/home/presentation/widgets/section_header.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final bool trailingFilter;
  const SectionHeader({
    super.key,
    required this.title,
    this.trailingFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textWhite,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailingFilter)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'All Countries',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.expand_more,
                    color: Colors.white70,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
