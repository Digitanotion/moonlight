import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class SocialAuthButton extends StatelessWidget {
  final String icon;
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;

  const SocialAuthButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.dark.withOpacity(0.3),
        foregroundColor: AppColors.textWhite,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.textWhite.withOpacity(0.2)),
        ),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // You can use an actual Google icon asset here
                const Icon(Icons.g_mobiledata, size: 24),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}
