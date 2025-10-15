import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class AppTextStyles {
  static const _fontFamily = 'Inter';
  // For onboarding title (large headline)
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );

  // For body text
  static const TextStyle bodyMedium = TextStyle(fontSize: 16, height: 1.5);

  // For buttons
  static const TextStyle labelLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static TextStyle titleLarge = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
    letterSpacing: 0.2,
  );
  static TextStyle titleMedium = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );
  static TextStyle body = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 1.4,
    color: AppColors.onSurface,
  );
  static TextStyle caption = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    color: AppColors.secondaryText,
  );
  static TextStyle small = const TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    color: AppColors.secondaryText,
  );
}
