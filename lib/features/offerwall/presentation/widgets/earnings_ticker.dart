// lib/features/offerwall/presentation/widgets/earnings_ticker.dart
//
// "Live earnings" card at the top of Home. A permanent, fixed-size glass
// card (it never slides away or collapses): a pulsing LIVE dot, a gradient
// initial avatar, who earned how many coins and how long ago, and a gold
// "+N" coin chip. Entries (real, recent Daily Tasks credits — first names
// only) rotate inside the card with a soft vertical slide + fade. With no
// recent activity it becomes a "Start earning" invitation instead of
// vanishing. Tapping opens Earn Cash.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/offerwall/data/datasources/offerwall_remote_data_source.dart';

const _gold = Color(0xFFFFC857);
const _amber = Color(0xFFFF8A00);
const _green = Color(0xFF2EE59D);

class EarningsTicker extends StatefulWidget {
  const EarningsTicker({super.key});

  @override
  State<EarningsTicker> createState() => _EarningsTickerState();
}

class _EarningsTickerState extends State<EarningsTicker>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _items = [];
  int _i = 0;
  Timer? _rotate;
  Timer? _refresh;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _load();
    _refresh = Timer.periodic(const Duration(minutes: 3), (_) => _load());
    _rotate = Timer.periodic(const Duration(milliseconds: 3600), (_) {
      if (!mounted || _items.length < 2) return;
      setState(() => _i = (_i + 1) % _items.length);
    });
  }

  @override
  void dispose() {
    _rotate?.cancel();
    _refresh?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await sl<OfferwallRemoteDataSource>().getRecentEarnings();
      if (!mounted) return;
      setState(() {
        _items = r;
        if (_i >= r.length) _i = 0;
      });
    } catch (_) {
      // Decorative: keep whatever is showing.
    }
  }

  String _ago(String? iso) {
    final t = DateTime.tryParse(iso ?? '')?.toLocal();
    if (t == null) return 'just now';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return 'today';
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = _items.isNotEmpty;
    final item = hasItems ? _items[_i % _items.length] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, RouteNames.dailyTasks),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1B2B8A).withValues(alpha: 0.85),
                    const Color(0xFF0A1040).withValues(alpha: 0.9),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: [
                  BoxShadow(
                    color: _amber.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _liveDot(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => ClipRect(
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.9),
                            end: Offset.zero,
                          ).animate(anim),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                      ),
                      child: hasItems ? _entry(item!) : _invite(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _liveDot() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) {
        final v = _pulse.value;
        return SizedBox(
          width: 22,
          height: 22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 8 + 12 * v,
                height: 8 + 12 * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _green.withValues(alpha: 0.28 * (1 - v)),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _green,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _entry(Map<String, dynamic> item) {
    final name = (item['name'] ?? 'Someone').toString();
    final coins = (item['coins'] ?? 0).toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      key: ValueKey('${item['name']}-${item['at']}-$coins'),
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_amber, Color(0xFFFF5B2E)]),
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name just earned',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'in free cash tasks · ${_ago(item['at']?.toString())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _gold.withValues(alpha: 0.14),
            border: Border.all(color: _gold.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                '+$coins',
                style: const TextStyle(
                  color: _gold,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _invite() {
    return Row(
      key: const ValueKey('invite'),
      children: [
        const Text('🪙', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Earn coins with free cash tasks',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Complete simple tasks, withdraw weekly',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
