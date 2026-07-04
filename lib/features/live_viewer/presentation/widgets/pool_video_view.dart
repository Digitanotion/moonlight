// lib/features/live_viewer/presentation/widgets/pool_video_view.dart
//
// REDESIGNED — no channelId matching, no per-item event filtering.
//
// The previous design had PoolVideoView keyed to a specific channelId,
// filtering pool events by channel. This was fragile: after rotation,
// the slot's channel changes but the widget's channelId doesn't, so
// events were silently dropped and the video never updated.
//
// New design: ONE widget that always renders the pool's CURRENT slot,
// whatever that is. It listens to the pool event stream and rebuilds
// whenever anything about the current slot changes — no channel guard,
// no epoch guard at the event level. The VideoViewController is rebuilt
// only when the actual (channel, hostUid) pair changes, which is the
// correct deduplication boundary.
//
// Usage: place ONE instance of this in ViewerModeScreen. Do NOT create
// one per PageView item. The PageView handles navigation; this widget
// handles video rendering for whichever stream is currently visible.

import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';

class PoolVideoView extends StatefulWidget {
  const PoolVideoView({
    super.key,
    required this.pool,
  });

  final AgoraEnginePool pool;

  /// The channel this widget instance is responsible for rendering.
  /// Derived from the key — used to filter events so only the visible
  /// page's PoolVideoView reacts when the pool's current slot changes.
  String? get _expectedChannel {
    final k = key;
    if (k is ValueKey) {
      final v = k.value?.toString() ?? '';
      // key format: 'pv_live_XwHXCQYGprrQ'
      if (v.startsWith('pv_')) return v.substring(3);
    }
    return null;
  }

  @override
  State<PoolVideoView> createState() => _PoolVideoViewState();
}

class _PoolVideoViewState extends State<PoolVideoView> {
  StreamSubscription<SlotEvent>? _sub;
  VideoViewController? _controller;
  bool _hasVideo = false;
  bool _disposed = false;

  // Track what the controller was built for — rebuild only on actual change.
  String? _controllerChannel;
  int? _controllerUid;

  @override
  void initState() {
    super.initState();
    _sub = widget.pool.events.listen(_onEvent);
    _seedFromCurrentSlot();
  }

  @override
  void didUpdateWidget(PoolVideoView old) {
    super.didUpdateWidget(old);
    if (old.pool != widget.pool) {
      _sub?.cancel();
      _sub = widget.pool.events.listen(_onEvent);
      _seedFromCurrentSlot();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _disposeController();
    super.dispose();
  }

  // ── Seed from whatever state the current slot is already in ───────────────

  void _seedFromCurrentSlot() {
    final slot = widget.pool.slotFor(SlotPosition.current);
    if (slot == null) return;
    // Only seed if this page's channel matches the current slot.
    final expected = widget._expectedChannel;
    if (expected != null && slot.channelId != null && slot.channelId != expected) return;
    if (slot.hostUid.value != null) {
      _buildController(slot);
    }
    if (slot.hasVideo.value && mounted) {
      setState(() => _hasVideo = true);
    }
  }

  // ── Event handler — no channel guard, just position guard ─────────────────

  void _onEvent(SlotEvent event) {
    if (_disposed || !mounted) return;
    if (event.position != SlotPosition.current) return;

    final slot = widget.pool.slotFor(SlotPosition.current);
    if (slot == null) return;

    // Only the page whose channel matches the pool's current slot
    // should react. This stops multiple PoolVideoView instances
    // (one per keepAlive page) from fighting each other.
    final expected = widget._expectedChannel;
    if (expected != null && slot.channelId != expected) return;

    switch (event.kind) {
      case SlotEventKind.joining:
        // Only clear if this is OUR channel starting a fresh join.
        // Do NOT clear if it's a different channel joining — that's
        // the background pre-join for another page, not us.
        if (slot.channelId == widget._expectedChannel && 
            slot.channelId != _controllerChannel) {
          _disposeController();
          if (mounted) setState(() => _hasVideo = false);
        }

      case SlotEventKind.joined:
        // Upgrade to high quality on current slot.
        final conn = slot.connection;
        if (conn != null && slot.hostUid.value != null) {
          widget.pool.sharedEngine
              .setRemoteVideoStreamTypeEx(
                uid: slot.hostUid.value!,
                streamType: VideoStreamType.videoStreamHigh,
                connection: conn,
              )
              .catchError((_) {});
          _buildController(slot);
        }
        // hostUidReady will fire shortly after if uid not yet known — handled below.

      case SlotEventKind.hostUidReady:
        _buildController(slot);

      case SlotEventKind.videoReady:
        _buildController(slot);
        if (mounted && !_hasVideo) setState(() => _hasVideo = true);

      case SlotEventKind.leftChannel:
      case SlotEventKind.joinFailed:
        // Only clear if the slot that left/failed is OUR channel.
        if (slot.channelId == widget._expectedChannel || 
            slot.channelId == _controllerChannel) {
          _disposeController();
          if (mounted) setState(() => _hasVideo = false);
        }
    }
  }

  // ── Controller management ─────────────────────────────────────────────────

  void _buildController(EngineSlot slot) {
    final hostUid = slot.hostUid.value;
    final channel = slot.channelId;
    if (hostUid == null || channel == null) return;

    // Only build for our expected channel.
    final expected = widget._expectedChannel;
    if (expected != null && channel != expected) return;

    // Already have a controller for this exact (channel, uid) — skip.
    if (_controllerChannel == channel &&
        _controllerUid == hostUid &&
        _controller != null) {
      debugPrint('🎮 [PoolVideoView] controller reuse: ch=$channel uid=$hostUid');
      return;
    }

    _disposeController();

    final connection = slot.connection;
    if (connection == null) return;

    try {
      final controller = VideoViewController.remote(
        rtcEngine: widget.pool.sharedEngine,
        useFlutterTexture: false,
        canvas: VideoCanvas(uid: hostUid),
        connection: connection,
      );

      _controllerChannel = channel;
      _controllerUid = hostUid;

      debugPrint(
        '🎮 [PoolVideoView] controller built: ch=$channel uid=$hostUid',
      );

      if (mounted) {
        setState(() {
          _controller = controller;
          if (slot.hasVideo.value) _hasVideo = true;
        });
      } else {
        _controller = controller;
      }
    } catch (e) {
      debugPrint('❌ [PoolVideoView] controller build failed: $e');
    }
  }

  void _disposeController() {
    try { _controller?.dispose(); } catch (_) {}
    _controller = null;
    _controllerChannel = null;
    _controllerUid = null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const _LoadingPlaceholder();
    }

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Wrap in a UniqueKey-keyed container to force full native
          // SurfaceView recreation when the stream changes. Without this,
          // Android reuses the same SurfaceView and the new stream's
          // frames never paint over the old surface.
          KeyedSubtree(
            key: ValueKey('surface_${_controllerChannel}_$_controllerUid'),
            child: AgoraVideoView(
              controller: _controller!,
            ),
          ),
          if (!_hasVideo) const _LoadingPlaceholder(),
        ],
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white38,
          ),
        ),
      ),
    );
  }
}