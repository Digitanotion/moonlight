// lib/features/offerwall/presentation/widgets/earn_cash_banner.dart
//
// The homepage/strategic-placement promo for the offerwall "Earn Cash"
// feature. Per the client, this stays permanently visible pre-activation —
// no user-dismiss anymore (the X was removed on request). It still hides
// for good once the user has actually activated, since at that point the
// permanent access point is the account menu's "Earn Cash" row (and the
// Wallet screen's actions sheet) — a "start earning" prompt stops making
// sense once they already have.
//
// Sits at the top of the page, not floating near the bottom nav. Same
// frosted-glass language as the bottom nav/account sheet: slim single-line
// pill, blur + translucency, no heavy card.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/offerwall/data/datasources/offerwall_remote_data_source.dart';

class EarnCashBanner extends StatefulWidget {
  const EarnCashBanner({super.key});

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
    try {
      final status = await sl<OfferwallRemoteDataSource>().getStatus();
      // Hidden only once genuinely activated — otherwise always shown, per
      // the client's "keep it permanent" request. An offline/error read
      // falls through to showing it rather than guessing it away.
      if (mounted) setState(() => _hidden = status['activated'] == true);
    } catch (_) {
      if (mounted) setState(() => _hidden = false);
    }
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
