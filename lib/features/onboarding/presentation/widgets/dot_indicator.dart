// dot_indicator.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_theme.dart';

class DotIndicator extends StatelessWidget {
  final int pageCount;
  final int currentPage;

  const DotIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 2.0,
          ), // space between dots
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            width: currentPage == index ? 15 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: currentPage == index
                  ? AppColors.primary
                  : AppColors.dotInactive,
              gradient: currentPage == index
                  ? LinearGradient(
                      colors: [AppColors.green, AppColors.green],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
