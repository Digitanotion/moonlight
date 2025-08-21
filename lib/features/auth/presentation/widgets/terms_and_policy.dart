import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_theme.dart';

class TermsAndPolicyText extends StatelessWidget {
  const TermsAndPolicyText({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textWhite),
          children: [
            const TextSpan(text: 'By signing up, you agree to our '),
            TextSpan(
              text: 'Terms',
              style: const TextStyle(
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  // Navigate to terms screen
                  // Navigator.pushNamed(context, RouteNames.terms);
                  // Navigator.pushReplacementNamed(context, RouteNames.interests);
                },
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: const TextStyle(
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  // Navigate to privacy policy screen
                  // Navigator.pushNamed(context, RouteNames.privacy);
                },
            ),
          ],
        ),
      ),
    );
  }
}
