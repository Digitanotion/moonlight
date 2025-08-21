import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/profile/domain/entities/interest.dart';

class InterestTile extends StatelessWidget {
  final Interest interest;
  final bool selected;
  final VoidCallback onTap;

  const InterestTile({
    super.key,
    required this.interest,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF161B2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: selected
              ? Border.all(color: AppColors.secondary, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            // Content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(interest.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 8),
                  Text(
                    interest.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Checkmark overlay when selected
            if (selected)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
