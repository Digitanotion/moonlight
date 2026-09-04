import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:moonlight/core/theme/app_colors.dart';

Widget _box({double? w, double? h, double r = 10}) => Container(
  width: w,
  height: h,
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(r),
  ),
);

Shimmer _shimmer({required Widget child}) => Shimmer.fromColors(
  baseColor: Colors.white.withOpacity(0.06),
  highlightColor: Colors.white.withOpacity(0.14),
  period: const Duration(milliseconds: 1400),
  child: child,
);

/// Horizontal row of suggested-club card skeletons.
class SuggestedClubsSkeleton extends StatelessWidget {
  const SuggestedClubsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: _shimmer(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => Container(
            width: 244,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(w: 150, h: 15),
                const SizedBox(height: 8),
                _box(w: 90, h: 11),
                const SizedBox(height: 14),
                _box(w: double.infinity, h: 34, r: 999),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A stack of full-width club-row skeletons.
class ClubRowsSkeleton extends StatelessWidget {
  final int count;
  const ClubRowsSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      child: Column(
        children: List.generate(
          count,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _box(w: 54, h: 54, r: 14),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(w: 140, h: 14),
                      const SizedBox(height: 8),
                      _box(w: 90, h: 11),
                    ],
                  ),
                ),
                _box(w: 60, h: 32, r: 999),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
