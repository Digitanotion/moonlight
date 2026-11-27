// lib/features/gifts/fx/gift_fx_layer.dart
//
// Plays full-screen gift animations over a live (viewer and host screens).
// Put it on top of the screen's Stack; it never takes touches. Gifts play
// one after another; the same person sending the same gift again while it
// is waiting just raises its "×N".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moonlight/features/gifts/fx/gift_fx_service.dart';
import 'package:moonlight/features/gifts/helpers/gift_visuals.dart';

class GiftFxLayer extends StatefulWidget {
  const GiftFxLayer({super.key});

  @override
  State<GiftFxLayer> createState() => _GiftFxLayerState();
}

class _Playing {
  final GiftFxEvent event;
  final int textureId;
  final double width;
  final double height;
  _Playing(this.event, this.textureId, this.width, this.height);
}

class _GiftFxLayerState extends State<GiftFxLayer>
    with TickerProviderStateMixin {
  final _fx = GiftFx.instance;
  final List<GiftFxEvent> _queue = [];
  static const _maxQueue = 8;

  StreamSubscription<GiftFxEvent>? _eventSub;
  StreamSubscription<(int, String)>? _playerSub;
  _Playing? _now;
  bool _busy = false;
  bool _visible = false;
  Timer? _safety;

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final AnimationController _banner = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    if (!_fx.supported) return;
    _eventSub = _fx.events.listen(_enqueue);
    _playerSub = _fx.playerEvents.listen(_onPlayerEvent);
    // Have the animations on the phone before anyone sends one (Wi-Fi only).
    unawaited(_fx.prefetchAll());
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _playerSub?.cancel();
    _safety?.cancel();
    final now = _now;
    if (now != null) {
      GiftFx.native.invokeMethod('stop', {'textureId': now.textureId});
    }
    _fade.dispose();
    _banner.dispose();
    super.dispose();
  }

  void _enqueue(GiftFxEvent e) {
    if (!_fx.hasFx(e.giftCode)) {
      // Catalog may not be loaded yet — load, then retry once.
      _fx.loadCatalog().then((_) {
        if (mounted && _fx.hasFx(e.giftCode)) _add(e);
      });
      return;
    }
    _add(e);
  }

  void _add(GiftFxEvent e) {
    // Same sender + same gift already waiting: count it there.
    for (var i = 0; i < _queue.length; i++) {
      final q = _queue[i];
      if (q.giftCode == e.giftCode &&
          q.senderName == e.senderName &&
          q.recipientName == e.recipientName) {
        _queue[i] = GiftFxEvent(
          giftCode: q.giftCode,
          giftTitle: q.giftTitle,
          senderName: q.senderName,
          senderAvatar: q.senderAvatar,
          recipientName: q.recipientName,
          quantity: q.quantity + e.quantity,
          coins: q.coins + e.coins,
        );
        return;
      }
    }
    if (_queue.length >= _maxQueue) return;
    _queue.add(e);
    _next();
  }

  Future<void> _next() async {
    if (_busy || _queue.isEmpty || !mounted) return;
    _busy = true;
    final e = _queue.removeAt(0);
    try {
      final path = await _fx
          .fileFor(e.giftCode)
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (path == null || !mounted) return _finish();
      final res = await GiftFx.native.invokeMapMethod<String, dynamic>('play', {
        'path': path,
        'volume': 1.0,
      });
      if (res == null || !mounted) return _finish();
      setState(() {
        _now = _Playing(
          e,
          (res['textureId'] as num).toInt(),
          (res['width'] as num).toDouble(),
          (res['height'] as num).toDouble(),
        );
        _visible = false;
      });
      // Never stuck: the longest animation is ~10s.
      _safety = Timer(const Duration(seconds: 16), _end);
    } catch (err) {
      debugPrint('⚠️ [GiftFx] play failed: $err');
      _finish();
    }
  }

  void _onPlayerEvent((int, String) ev) {
    final now = _now;
    if (now == null || ev.$1 != now.textureId) return;
    switch (ev.$2) {
      case 'firstFrame':
        if (!mounted) return;
        setState(() => _visible = true);
        _fade.forward(from: 0);
        _banner.forward(from: 0);
      case 'completed':
      case 'error':
        _end();
    }
  }

  Future<void> _end() async {
    _safety?.cancel();
    final now = _now;
    if (now == null) return;
    if (mounted && _visible) {
      _banner.reverse();
      await _fade.reverse();
    }
    GiftFx.native.invokeMethod('stop', {'textureId': now.textureId});
    if (mounted) setState(() => _now = null);
    _finish();
  }

  void _finish() {
    _busy = false;
    if (mounted) {
      // A breath between gifts.
      Future.delayed(const Duration(milliseconds: 180), _next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    if (now == null) return const SizedBox.shrink();
    final top = MediaQuery.paddingOf(context).top;

    // The animation itself is drawn by a native see-through view over the
    // app (GiftFxChannel.kt); Flutter only shows who sent it.
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_visible)
            Positioned(
              top: top + 86,
              left: 10,
              right: 60,
              child: FadeTransition(
                opacity: _fade,
                child: _Banner(event: now.event, animation: _banner),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Name sent Moon ×2" — slides in at the top-left while the gift plays.
class _Banner extends StatelessWidget {
  final GiftFxEvent event;
  final Animation<double> animation;
  const _Banner({required this.event, required this.animation});

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(-1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));
    final initial = event.senderName.trim().isEmpty
        ? '?'
        : event.senderName.trim()[0].toUpperCase();
    return Align(
      alignment: Alignment.centerLeft,
      child: SlideTransition(
        position: slide,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xE6FF8A00), Color(0xCCFF3D81), Color(0x99A24BFF)],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x66FF7A00), blurRadius: 18),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFF2A1840),
                backgroundImage: (event.senderAvatar ?? '').startsWith('http')
                    ? NetworkImage(event.senderAvatar!)
                    : null,
                child: (event.senderAvatar ?? '').startsWith('http')
                    ? null
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      event.recipientName == null
                          ? 'sent ${event.giftTitle}'
                          : 'sent ${event.recipientName} ${event.giftTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFF1C9),
                        fontSize: 12,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                height: 34,
                child: FutureBuilder<Widget>(
                  future: GiftVisuals.build(
                    event.giftCode,
                    size: 34,
                    title: event.giftTitle,
                  ),
                  builder: (_, s) => s.data ?? const SizedBox.shrink(),
                ),
              ),
              if (event.quantity > 1) ...[
                const SizedBox(width: 6),
                Text(
                  '×${event.quantity}',
                  style: const TextStyle(
                    color: Color(0xFFFFE083),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    shadows: [Shadow(color: Color(0xAA000000), blurRadius: 6)],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
