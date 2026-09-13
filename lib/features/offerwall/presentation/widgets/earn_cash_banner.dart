// lib/features/offerwall/presentation/widgets/earn_cash_banner.dart
//
// The homepage/strategic-placement promo for the offerwall "Earn Cash"
// feature. Copy is verbatim from the client's brief. Dismissible — a
// dismissal hides it for 24h (not forever), since this is a revenue feature
// worth resurfacing, not a one-time tip. Once the user actually activates
// Daily Tasks, this banner should simply stop being shown by whoever embeds
// it (check OfferwallCubit.state.activated) rather than via this widget's
// own dismiss state.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonlight/core/routing/route_names.dart';

class EarnCashBanner extends StatefulWidget {
  const EarnCashBanner({super.key});

  static const _dismissedUntilKey = 'earn_cash_banner_dismissed_until_v1';

  @override
  State<EarnCashBanner> createState() => _EarnCashBannerState();
}

class _EarnCashBannerState extends State<EarnCashBanner> {
  bool _hidden = true; // hidden until we've checked prefs, avoids a flash

  @override
  void initState() {
    super.initState();
    _checkDismissed();
  }

  Future<void> _checkDismissed() async {
    final sp = await SharedPreferences.getInstance();
    final until = sp.getInt(EarnCashBanner._dismissedUntilKey) ?? 0;
    final stillDismissed = DateTime.now().millisecondsSinceEpoch < until;
    if (mounted) setState(() => _hidden = stillDismissed);
  }

  Future<void> _dismiss() async {
    setState(() => _hidden = true);
    final sp = await SharedPreferences.getInstance();
    final until = DateTime.now().add(const Duration(hours: 24));
    await sp.setInt(
      EarnCashBanner._dismissedUntilKey,
      until.millisecondsSinceEpoch,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF0E8F5B), Color(0xFF1FBF75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1FBF75).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.pushNamed(context, RouteNames.dailyTasks),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    alignment: Alignment.center,
                    child: const Text('💰', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Earn free cash daily here and withdraw your '
                          'cash easily by completing simple tasks.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Tap below to start earning instantly.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Start Earning Now',
                                style: TextStyle(
                                  color: Color(0xFF0E8F5B),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: Color(0xFF0E8F5B),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _DismissButton(onTap: _dismiss),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DismissButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.close_rounded,
          size: 16,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
