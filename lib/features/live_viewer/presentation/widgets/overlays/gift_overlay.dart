// lib/features/live_viewer/presentation/widgets/overlays/gift_overlay.dart
//
// Viewer-side gift "splash": when anyone in the room sends a gift, this
// animates in from the left with a bounce + glow, shows the real gift
// artwork, then fades away. Driven by ViewerBloc (showGiftToast / gift),
// which is fed by the `gift.sent` broadcast for every viewer.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';

class GiftOverlay extends StatelessWidget {
  const GiftOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) =>
          p.showGiftToast != n.showGiftToast || p.gift != n.gift,
      builder: (_, s) {
        final g = s.gift;
        if (!s.showGiftToast || g == null) return const SizedBox.shrink();

        final hostName = s.host?.name ?? 'the host';
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 180),
            // key on the gift so a new gift restarts the entrance animation
            child: _GiftSplash(
              key: ValueKey('${g.from}|${g.giftName}|${g.coins}|${s.showGiftToast}'),
              from: g.from,
              hostName: hostName,
              giftName: g.giftName,
              coins: g.coins,
            ),
          ),
        );
      },
    );
  }
}

class _GiftSplash extends StatefulWidget {
  final String from;
  final String hostName;
  final String giftName;
  final int coins;

  const _GiftSplash({
    super.key,
    required this.from,
    required this.hostName,
    required this.giftName,
    required this.coins,
  });

  @override
  State<_GiftSplash> createState() => _GiftSplashState();
}

class _GiftSplashState extends State<_GiftSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(-1.1, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.12), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 55),
  ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x59FFB020), Color(0x4DFF3D81), Color(0x3AA24BFF)],
                ),
                border: Border.all(color: const Color(0x80FFD27A)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7A00).withOpacity(0.28),
                    blurRadius: 22,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GiftArt(name: widget.giftName),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                height: 1.3),
                            children: [
                              TextSpan(
                                text: widget.from,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFFD27A)),
                              ),
                              const TextSpan(text: ' sent '),
                              TextSpan(
                                text: widget.hostName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: '  ${widget.giftName}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFFE7B0)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding:
                              const EdgeInsets.fromLTRB(4, 1, 7, 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withOpacity(0.24),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.south_rounded,
                                  size: 12, color: Color(0xFF4ADE80)),
                              const SizedBox(width: 2),
                              Text(
                                '${widget.coins} coins',
                                style: const TextStyle(
                                    color: Color(0xFF4ADE80),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Best-effort: GiftNotice only carries the gift *name*, so match it to a
/// code by slugifying, then let GiftVisuals resolve the artwork.
class _GiftArt extends StatelessWidget {
  final String name;
  const _GiftArt({required this.name});

  @override
  Widget build(BuildContext context) {
    final code = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    return SizedBox(
      width: 38,
      height: 38,
      child: FutureBuilder<Widget>(
        future: GiftVisuals.build(code, size: 38, title: name),
        builder: (_, snap) =>
            snap.data ??
            const Icon(Icons.card_giftcard_rounded,
                size: 26, color: Color(0xFFFFD27A)),
      ),
    );
  }
}
