// skip_button.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_theme.dart';

import 'package:moonlight/core/widgets/app_logo_loader.dart';

class SkipButton extends StatelessWidget {
  final VoidCallback? onPressed; // ✅ Change to nullable
  final bool isLoading;

  const SkipButton({
    super.key,
    this.onPressed, // ✅ Now can be null
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isLoading ? null : onPressed, // ✅ Already handles null
      child: isLoading
          ? SizedBox(width: 20, height: 20, child: AppLogoLoader())
          : Text(
              'Skip >>',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
