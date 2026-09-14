// lib/features/offerwall/presentation/widgets/earn_cash_banner.dart
//
// The homepage/strategic-placement promo for the offerwall "Earn Cash"
// feature. This is purely a pre-activation discovery nudge, not the
// feature's only door — once activated, the permanent access point is the
// account menu's "Earn Cash" row (and the Wallet screen's actions sheet),
// so this banner stops showing entirely (not just dismissed-for-24h) the
// moment activation is confirmed. Before activation, a dismissal hides it
// for 24h rather than forever, since this is a revenue feature worth
// resurfacing, not a one-time tip.
//
// Sits at the top of the page, not floating near the bottom nav — it's
// dismissible and transient, so it reads more like a top notice than a
// persistent action bar. Same frosted-glass language as the bottom nav/
// account sheet: slim single-line pill, blur + translucency, no heavy card.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/offerwall/data/datasources/offerwall_remote_data_source.dart';

class EarnCashBanner extends StatefulWidget {
  const EarnCashBanner({super.key});

  static const _dismissedUntilKey = 'earn_cash_banner_dismissed_until_v1';

  @override
  State<EarnCashBanner> createState() => _EarnCashBannerState();
}

class _EarnCashBannerState extends State<EarnCashBanner> {
  bool _hidden = true; // hidden until we've checked, avoids a flash

  @override
  void initState() {
    super.initState();
    _checkVisibility();
  }

  Future<void> _checkVisibility() async {
    // Authoritative check first — once activated, this banner is done for
    // good, regardless of any past dismiss timer.
    try {
      final status = await sl<OfferwallRemoteDataSource>().getStatus();
      if (status['activated'] == true) {
        if (mounted) setState(() => _hidden = true);
        return;
      }
    } catch (_) {
      // Offline/error — fall through to the local dismiss check rather
      // than failing closed or open on a guess.
    }

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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Material(
            color: const Color(0xFF1FBF75).withValues(alpha: 0.16),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, RouteNames.dailyTasks),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF1FBF75).withValues(alpha: 0.35),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Earn free cash daily — tap to start',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Color(0xFF6CE8A8),
                    ),
                    const SizedBox(width: 8),
                    _DismissButton(onTap: _dismiss),
                  ],
                ),
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
        padding: const EdgeInsets.all(2),
        child: Icon(
          Icons.close_rounded,
          size: 15,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
