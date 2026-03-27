import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/widgets/web_view_screen.dart';

class TermsAndPolicyText extends StatelessWidget {
  const TermsAndPolicyText({super.key});

  static const _termsUrl = 'https://moonlightstream.app/terms';
  static const _privacyUrl = 'https://moonlightstream.app/privacy-policy';

  void _openWebView(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewScreen(title: title, url: url),
      ),
    );
  }

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
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _openWebView(
                  context,
                  title: 'Terms of Service',
                  url: _termsUrl,
                ),
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: const TextStyle(
                color: AppColors.primary,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _openWebView(
                  context,
                  title: 'Privacy Policy',
                  url: _privacyUrl,
                ),
            ),
          ],
        ),
      ),
    );
  }
}
