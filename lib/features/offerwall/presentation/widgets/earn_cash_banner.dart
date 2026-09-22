// lib/features/offerwall/presentation/widgets/earn_cash_banner.dart
//
// The Watch-tab-only promo for the offerwall "Earn Cash" feature — floats
// over the video/live grid with a dimmed backdrop, styled after a reference
// screenshot of a flashy in-app purchase promo: a glowing hero icon behind
// rotating sunburst rays, twinkling sparkle particles, drifting balloons,
// a starburst discount-style badge, and a bold gradient CTA. Only rendered
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
    with TickerProviderStateMixin {
  bool _hidden = true; // hidden until we've checked, avoids a flash
  bool _dismissedThisSession = false;

  late final AnimationController _glowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  late final AnimationController _rayCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _checkVisibility();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _rayCtrl.dispose();
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
              child: Container(color: Colors.black.withValues(alpha: 0.65)),
            ),
          ),
          // Balloons drift across the whole dimmed area, behind the card —
          // painted before it in the Stack, ignoring pointer events.
          const Positioned.fill(
            child: IgnorePointer(child: _FloatingBalloons()),
          ),
          Align(
            alignment: const Alignment(0, -0.25),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
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
                        // A layered "picture frame" — a thin outer gold
                        // line with a gap before the card itself — instead
                        // of one flat border, so the outline itself reads
                        // as ornate rather than a plain rounded rectangle.
                        return Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(
                                0xFFFFD180,
                              ).withValues(alpha: 0.55 + t * 0.25),
                              width: 1.2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF4A1D00),
                                      Color(0xFF120600),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.5 + t * 0.35,
                                    ),
                                    width: 1.6,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.secondary.withValues(
                                        alpha: 0.28 + t * 0.22,
                                      ),
                                      blurRadius: 30 + t * 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 60, 18, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Earn Real Cash Daily',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
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
                            const SizedBox(height: 20),
                            _CtaButton(controller: _glowCtrl),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Hero icon — sits ABOVE the card, breaking through its
                  // top edge (clipBehavior: none lets it overflow), so the
                  // card's silhouette doesn't read as a plain rectangle
                  // with an icon politely sitting inside it, matching the
                  // reference's treasure-chest-bursting-through-the-top
                  // composition.
                  Positioned(
                    top: -64,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SizedBox(
                        width: 118,
                        height: 118,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _SunburstRays(controller: _rayCtrl),
                            const Positioned(
                              top: -4,
                              left: 6,
                              child: _Sparkle(size: 14, delay: 0.0),
                            ),
                            const Positioned(
                              bottom: 2,
                              right: 2,
                              child: _Sparkle(size: 10, delay: 0.4),
                            ),
                            const Positioned(
                              top: 10,
                              right: -6,
                              child: _Sparkle(size: 12, delay: 0.7),
                            ),
                            _GlowIcon(controller: _glowCtrl),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Starburst badge, perched on the card's top-right
                  // corner — outside the card's own bounds via
                  // clipBehavior: none, same technique already used for
                  // the LIVE badge/dancing icon in home_top_tabs.dart.
                  const Positioned(top: -20, right: 2, child: _Starburst()),
                  // Dismiss — a plain sibling of the tappable card (not
                  // nested inside its GestureDetector), so tapping it can
                  // never also trigger the "open Daily Tasks" navigation.
                  Positioned(
                    top: 10,
                    left: 10,
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
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.secondary, AppColors.primary2],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.45 + t * 0.3),
                blurRadius: 26 + t * 14,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text('💰', style: TextStyle(fontSize: 30)),
        );
      },
    );
  }
}

/// Slowly-rotating light rays behind the hero icon — a classic "magical
/// glow" treatment for a promo/reward hero graphic, drawn once with
/// CustomPainter rather than needing illustration assets.
class _SunburstRays extends StatelessWidget {
  final AnimationController controller;
  const _SunburstRays({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Transform.rotate(
          angle: controller.value * 2 * math.pi,
          child: CustomPaint(
            size: const Size(118, 118),
            painter: _RaysPainter(),
          ),
        );
      },
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide / 2;
    const rayCount = 12;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.secondary.withValues(alpha: 0.55),
          AppColors.secondary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));

    for (var i = 0; i < rayCount; i++) {
      final angle = (2 * math.pi / rayCount) * i;
      final path = Path();
      final halfWidth = 0.11;
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + outerRadius * math.cos(angle - halfWidth),
        center.dy + outerRadius * math.sin(angle - halfWidth),
      );
      path.lineTo(
        center.dx + outerRadius * math.cos(angle + halfWidth),
        center.dy + outerRadius * math.sin(angle + halfWidth),
      );
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter oldDelegate) => false;
}

/// A single twinkling star — opacity and scale pulse on a loop, offset by
/// [delay] (0.0–1.0 of the cycle) so a cluster of these never blinks in
/// sync.
class _Sparkle extends StatefulWidget {
  final double size;
  final double delay;
  const _Sparkle({required this.size, required this.delay});

  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final phase = (_ctrl.value + widget.delay) % 1.0;
        final t = Curves.easeInOut.transform(
          phase < 0.5 ? phase * 2 : (1 - phase) * 2,
        );
        return Opacity(
          opacity: 0.25 + t * 0.75,
          child: Transform.scale(
            scale: 0.6 + t * 0.5,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: widget.size,
              color: Colors.amberAccent.withValues(alpha: 0.9),
            ),
          ),
        );
      },
    );
  }
}

/// A handful of emoji balloons drifting gently up and down around the
/// card, each on its own phase/speed so they read as loosely floating
/// rather than mechanically synced. Cheap, reliable across platforms —
/// no custom illustration assets needed.
class _FloatingBalloons extends StatelessWidget {
  const _FloatingBalloons();

  static const _balloons = [
    (align: Alignment(-0.92, -0.7), size: 34.0, period: 3400, delay: 0.0),
    (align: Alignment(0.88, -0.55), size: 26.0, period: 2800, delay: 0.3),
    (align: Alignment(-0.8, 0.55), size: 24.0, period: 3100, delay: 0.6),
    (align: Alignment(0.9, 0.72), size: 30.0, period: 3700, delay: 0.15),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final b in _balloons)
          Align(
            alignment: b.align,
            child: _Balloon(size: b.size, period: b.period, delay: b.delay),
          ),
      ],
    );
  }
}

class _Balloon extends StatefulWidget {
  final double size;
  final int period;
  final double delay;
  const _Balloon({
    required this.size,
    required this.period,
    required this.delay,
  });

  @override
  State<_Balloon> createState() => _BalloonState();
}

class _BalloonState extends State<_Balloon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.period),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final phase = (_ctrl.value + widget.delay) % 1.0;
        final bob = math.sin(phase * 2 * math.pi) * 10;
        final sway = math.sin(phase * 2 * math.pi * 0.6) * 6;
        return Transform.translate(
          offset: Offset(sway, bob),
          child: Opacity(
            opacity: 0.85,
            child: Text('🎈', style: TextStyle(fontSize: widget.size)),
          ),
        );
      },
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
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(
              colors: [AppColors.secondary, AppColors.primary2],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.45 + t * 0.3),
                blurRadius: 18 + t * 10,
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
              fontSize: 15.5,
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
/// A real jagged burst outline (CustomPainter, alternating spike/valley
/// radius around the circle) instead of two overlapping rotated squares —
/// the squares read as "a regular square", not a sticker-style starburst.
class _Starburst extends StatelessWidget {
  const _Starburst();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(78, 78), painter: _StarburstPainter()),
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
}

class _StarburstPainter extends CustomPainter {
  static const _points = 14;
  static const _innerRatio = 0.72; // valley depth relative to outer radius

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide / 2;
    final innerRadius = outerRadius * _innerRatio;

    final path = Path();
    for (var i = 0; i < _points * 2; i++) {
      final angle = (math.pi / _points) * i - math.pi / 2;
      final radius = i.isEven ? outerRadius : innerRadius;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    final rect = Rect.fromCircle(center: center, radius: outerRadius);

    // Soft glow halo, painted first so the solid fill sits cleanly on top
    // of it instead of the blur smearing over the star's crisp edges.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF3B30).withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF3B30), Color(0xFFFF8A00)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _StarburstPainter oldDelegate) => false;
}
