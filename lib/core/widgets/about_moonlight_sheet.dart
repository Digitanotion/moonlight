// lib/core/widgets/about_moonlight_sheet.dart
//
// "About Moonlight" — opened by tapping the logo in the home app bar.
// Links to the marketing site's About / Legal pages open in a
// chrome-less in-app web view (looks native, no browser toolbar).
// Contact / social links open in their native apps.

import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/widgets/web_view_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// All external destinations, kept in one place.
class MoonlightLinks {
  static const site = 'https://moonlightstream.app';

  // About
  static const ourStory = '$site/our-story';
  static const careers = '$site/career';
  static const press = '$site/press';

  // Legal
  static const termsAndCondition = '$site/terms-and-condition';
  static const termsOfService = '$site/terms-of-services';
  static const privacyPolicy = '$site/privacy-policy';
  static const cookiePolicy = '$site/cookies-policy';
  static const refundPolicy = '$site/refund-policy';
  static const communityGuidelines = '$site/community-guidelines';

  // Contact / social
  static const supportEmail = 'okwupat2003@gmail.com';
  static const supportPhone = '+2348037525545';
  static const facebook = 'https://facebook.com/moonlightlivestreamapp';
  static const tiktok = 'https://www.tiktok.com/@moonlight.livestream';
  static const linkedin =
      'https://www.linkedin.com/company/franokwy-ventures-ltd/';
}

Future<void> showAboutMoonlightSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AboutMoonlightSheet(),
  );
}

class _AboutMoonlightSheet extends StatefulWidget {
  const _AboutMoonlightSheet();

  @override
  State<_AboutMoonlightSheet> createState() => _AboutMoonlightSheetState();
}

class _AboutMoonlightSheetState extends State<_AboutMoonlightSheet> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    }).catchError((_) {});
  }

  void _openPage(BuildContext context, String title, String url) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebViewScreen(title: title, url: url)),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navy, AppColors.bgBottom],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white24, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
              child: Column(
                children: [
                  Image.asset('assets/images/logo.png', width: 72, height: 72),
                  const SizedBox(height: 14),
                  const Text(
                    'Moonlight',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_version.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Version $_version',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Go live, catch fun, and earn gifts. Join clubs, climb '
                    'the ranks, and connect with a global community.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _LinkGroup(
                    label: 'Company',
                    children: [
                      _LinkRow(
                        icon: Icons.auto_stories_outlined,
                        label: 'Our story',
                        onTap: () => _openPage(
                          context,
                          'Our Story',
                          MoonlightLinks.ourStory,
                        ),
                      ),
                      _LinkRow(
                        icon: Icons.work_outline_rounded,
                        label: 'Careers',
                        onTap: () => _openPage(
                          context,
                          'Careers',
                          MoonlightLinks.careers,
                        ),
                      ),
                      _LinkRow(
                        icon: Icons.article_outlined,
                        label: 'Press',
                        onTap: () => _openPage(
                          context,
                          'Press',
                          MoonlightLinks.press,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _LinkGroup(
                    label: 'Legal',
                    children: [
                      _LinkRow(
                        icon: Icons.description_outlined,
                        label: 'Terms and Conditions',
                        onTap: () => _openPage(
                          context,
                          'Terms and Conditions',
                          MoonlightLinks.termsAndCondition,
                        ),
                      ),
                      _LinkRow(
                        icon: Icons.gavel_rounded,
                        label: 'Terms of Service',
                        onTap: () => _openPage(
                          context,
                          'Terms of Service',
                          MoonlightLinks.termsOfService,
                        ),
                      ),
                      _LinkRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        onTap: () => _openPage(
                          context,
                          'Privacy Policy',
                          MoonlightLinks.privacyPolicy,
                        ),
                      ),
                      _LinkRow(
                        icon: Icons.cookie_outlined,
                        label: 'Cookie Policy',
                        onTap: () => _openPage(
                          context,
                          'Cookie Policy',
                          MoonlightLinks.cookiePolicy,
                        ),
                      ),
                      _LinkRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Refund Policy',
                        onTap: () => _openPage(
                          context,
                          'Refund Policy',
                          MoonlightLinks.refundPolicy,
                        ),
                      ),
                      _LinkRow(
                        icon: Icons.shield_outlined,
                        label: 'Community Guidelines',
                        onTap: () => _openPage(
                          context,
                          'Community Guidelines',
                          MoonlightLinks.communityGuidelines,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _LinkGroup(
                    label: 'Contact',
                    children: [
                      _LinkRow(
                        icon: Icons.mail_outline_rounded,
                        label: MoonlightLinks.supportEmail,
                        onTap: () => _launch(
                          'mailto:${MoonlightLinks.supportEmail}',
                        ),
                      ),
                      _LinkRow(
                        icon: Icons.call_outlined,
                        label: MoonlightLinks.supportPhone,
                        onTap: () => _launch(
                          'tel:${MoonlightLinks.supportPhone}',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialButton(
                        icon: Icons.facebook_rounded,
                        onTap: () => _launch(MoonlightLinks.facebook),
                      ),
                      const SizedBox(width: 14),
                      _SocialButton(
                        icon: Icons.music_note_rounded,
                        onTap: () => _launch(MoonlightLinks.tiktok),
                      ),
                      const SizedBox(width: 14),
                      _SocialButton(
                        icon: Icons.business_center_rounded,
                        onTap: () => _launch(MoonlightLinks.linkedin),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Owned and managed by Franokwy Ventures Ltd\n'
                    'Awka South, Anambra State, Nigeria',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '© 2026 Moonlight. All rights reserved.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _LinkGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 52,
                    color: Colors.white.withOpacity(0.06),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white.withOpacity(0.75)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.white.withOpacity(0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SocialButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, size: 20, color: Colors.white.withOpacity(0.8)),
      ),
    );
  }
}
