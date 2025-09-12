import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

BoxDecoration gradientBg() {
  return const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.bgTop, AppColors.bgBottom],
    ),
  );
}

InputDecoration inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.cardDark,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
  );
}

Widget sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Text(
    text,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  ),
);
