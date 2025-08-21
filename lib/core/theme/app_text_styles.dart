import 'package:flutter/material.dart';

class AppTextStyles {
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
}
