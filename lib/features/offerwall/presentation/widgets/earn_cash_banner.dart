// lib/features/offerwall/presentation/widgets/earn_cash_banner.dart
//
// The Watch-tab-only promo for the offerwall "Earn Cash" feature — floats
// over the video/live grid with a dimmed backdrop, styled after a reference
// screenshot of a flashy in-app purchase promo (glow border, a starburst
// badge, a ticket-style price callout, a bold gradient CTA). Only rendered
// while the Watch tab is active (see home_top_tabs.dart, which gates this
// widget on _tabs.index == 0) — this widget itself doesn't know or care
// which tab it's on, it just fills whatever Stack it's given.
//
// Dismissible via a close button in the top-left corner — session-only
// (resets on next cold launch), not persisted. Also hides for good once
// the user has actually activated, since at that point the permanent
// access point is the account menu's "Earn Cash" row (and the Wallet
// screen's actions sheet) — a "start earning" prompt stops making sense
// once they already have.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/offerwall/data/datasources/offerwall_remote_data_source.dart';

class EarnCashBanner extends StatefulWidget {
  const EarnCashBanner({super.key});

  @override
  State<EarnCashBanner> createState() => _EarnCashBannerState();
}

class _EarnCashBannerState extends State<EarnCashBanner>
    with SingleTickerProviderStateMixin {
  bool _hidden = true; // hidden until we've checked, avoids a flash
  bool _dismissedThisSession = false;

  late final AnimationController _glowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _checkVisibility();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
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
    if (_hidden || _dismissedThisSession) return const SizedBox.shrink();

    // Floats over the Watch tab's content behind it, dimming it, rather
    // than sitting inline in the page's normal flow — this widget is a
    // direct Stack sibling of the TabBarView in home_top_tabs.dart (which
    // only renders it while the Watch tab is active), sized to that same
    // content area — below the header/tabs, above the bottom nav, neither
    // of which this overlay covers since its Stack ancestor only spans
    // the content region.
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              // Absorbs taps so they don't fall through to the grid
              // underneath — deliberately doesn't dismiss on tap; only
              // the close button does, so it can't be swiped away by
              // accident.
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.dailyTasks),
                    child: AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (context, child) {
                        final t = Curves.easeInOut.transform(_glowCtrl.value);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF3A1500),
                                    Color(0xFF160800),
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.45 + t * 0.3,
                                  ),
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.22 + t * 0.18,
                                    ),
                                    blurRadius: 22 + t * 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 34, 18, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _GlowIcon(controller: _glowCtrl),
                            const SizedBox(height: 10),
                            const Text(
                              'Earn Real Cash Daily',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Complete simple tasks — get paid weekly',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _PriceTicket(),
                            const SizedBox(height: 16),
                            _CtaButton(controller: _glowCtrl),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Starburst badge, perched on the card's top-right
                  // corner — outside the card's own bounds via
                  // clipBehavior: none, same technique already used for
                  // the LIVE badge/dancing icon in home_top_tabs.dart.
                  const Positioned(top: -16, right: 6, child: _Starburst()),
                  // Dismiss — a plain sibling of the tappable card (not
                  // nested inside its GestureDetector), so tapping it can
                  // never also trigger the "open Daily Tasks" navigation.
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _CloseButton(
                      onTap: () => setState(() => _dismissedThisSession = true),
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

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white70, size: 15),
      ),
    );
  }
}

class _GlowIcon extends StatelessWidget {
  final AnimationController controller;
  const _GlowIcon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(controller.value);
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.secondary, AppColors.primary2],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.35 + t * 0.25),
                blurRadius: 20 + t * 10,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text('💰', style: TextStyle(fontSize: 28)),
        );
      },
    );
  }
}

/// Ticket-shaped "what it costs to unlock this" callout — echoes the
/// reference screenshot's "NOW ONLY $0.5" ticket, but honestly showing the
/// real one-time activation cost instead of a fake urgency price.
class _PriceTicket extends StatelessWidget {
  const _PriceTicket();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.confirmation_number_rounded,
            size: 16,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 8),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                color: Color(0xFF160800),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
              children: [
                TextSpan(text: 'Activate for 100 coins '),
                TextSpan(
                  text: '(\$1)',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final AnimationController controller;
  const _CtaButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(controller.value);
        return Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [AppColors.secondary, AppColors.primary2],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.4 + t * 0.25),
                blurRadius: 16 + t * 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '»  Start Earning  «',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        );
      },
    );
  }
}

/// Two overlapping rotated rounded squares behind text — the classic cheap
/// "sticker starburst" trick, no custom painting needed.
class _Starburst extends StatelessWidget {
  const _Starburst();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(angle: 0, child: _spike()),
          Transform.rotate(angle: math.pi / 4, child: _spike()),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              '70%\nTO YOU',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spike() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFFF8A00)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
            blurRadius: 14,
          ),
        ],
      ),
    );
  }
}
