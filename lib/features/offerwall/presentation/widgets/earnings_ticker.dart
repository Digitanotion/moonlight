// lib/features/offerwall/presentation/widgets/earnings_ticker.dart
//
// The sliding "John has just earned 42 coins in the free cash tasks" strip
// across the top of Home. Shows real, recent Daily Tasks earnings from the
// API (first names only), one at a time: slides in from the right, rests
// a few seconds, slides out left, then the next. Tapping opens Earn Cash.
// Hidden when there's nothing to show; never blocks or breaks Home if the
// request fails.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/offerwall/data/datasources/offerwall_remote_data_source.dart';

class EarningsTicker extends StatefulWidget {
  const EarningsTicker({super.key});

  @override
  State<EarningsTicker> createState() => _EarningsTickerState();
}

class _EarningsTickerState extends State<EarningsTicker>
    with SingleTickerProviderStateMixin {
  static const _rest = Duration(milliseconds: 3200);

  late final AnimationController _c;
  List<Map<String, dynamic>> _items = [];
  int _i = 0;
  bool _running = false;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _load();
    // Pick up fresh earnings every few minutes.
    _refresh = Timer.periodic(const Duration(minutes: 3), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await sl<OfferwallRemoteDataSource>().getRecentEarnings();
      if (!mounted) return;
      setState(() => _items = r);
      if (r.isNotEmpty && !_running) _loop();
    } catch (_) {
      // Decorative feature: stay quiet on failure.
    }
  }

  Future<void> _loop() async {
    _running = true;
    while (mounted && _items.isNotEmpty) {
      if (_i >= _items.length) _i = 0;
      setState(() {});
      try {
        await _c.forward(from: 0); // slide in
        await Future.delayed(_rest);
        if (!mounted) break;
        await _c.reverse(); // slide out
        await Future.delayed(const Duration(milliseconds: 600));
      } catch (_) {
        break; // controller disposed mid-animation
      }
      _i++;
    }
    _running = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final item = _items[_i % _items.length];
    final name = (item['name'] ?? 'Someone').toString();
    final coins = (item['coins'] ?? 0).toString();

    final slide = Tween<Offset>(
      begin: const Offset(1.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);

    return SizedBox(
      height: 44,
      width: double.infinity,
      child: ClipRect(
        child: SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: fade,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, RouteNames.dailyTasks),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A2A7A), Color(0xFF0B1240)],
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFB347).withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8A00).withValues(alpha: 0.25),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: RichText(
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(text: ' has just earned '),
                              TextSpan(
                                text: '$coins coins',
                                style: const TextStyle(
                                  color: Color(0xFFFFC857),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(text: ' in the free cash tasks'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
