// lib/features/live_viewer/presentation/widgets/pool_video_view.dart
//
// PRODUCTION VERSION — diagnostic logging stripped after confirming the
// fix (event handler registration timing in agora_engine_pool.dart)
// resolved video rendering. Core logic is unchanged from the verified
// version: build the controller once per (epoch, uid) pair, mount
// AgoraVideoView as soon as the controller exists (loading spinner
// overlaid on top, not replacing it), seed from current slot state on
// attach to catch up on anything that fired before this widget mounted.

import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';

class PoolVideoView extends StatefulWidget {
  const PoolVideoView({super.key, required this.pool, required this.channelId});

  final AgoraEnginePool pool;
  final String channelId;

  @override
  State<PoolVideoView> createState() => _PoolVideoViewState();
}

class _PoolVideoViewState extends State<PoolVideoView> {
  StreamSubscription<SlotEvent>? _sub;
  VideoViewController? _controller;
  bool _hasVideo = false;
  bool _disposed = false;
  int? _controllerEpoch;
  int? _controllerUid;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(PoolVideoView old) {
    super.didUpdateWidget(old);
    if (old.channelId != widget.channelId || old.pool != widget.pool) {
      _detach();
      _attach();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _detach();
    super.dispose();
  }

  void _attach() {
    _sub = widget.pool.events.listen(_onEvent);
    _seedFromCurrentSlotState();
  }

  void _detach() {
    _sub?.cancel();
    _sub = null;
    _disposeController();
  }

  void _seedFromCurrentSlotState() {
    final slot = widget.pool.slotFor(SlotPosition.current);
    if (slot == null) return;
    if (slot.channelId != widget.channelId) return;

    if ((slot.state == SlotJoinState.joined ||
            slot.state == SlotJoinState.joining) &&
        slot.hostUid.value != null) {
      _buildControllerOnce(slot);
    }

    if (slot.hasVideo.value && mounted) {
      setState(() => _hasVideo = true);
    }
  }

  void _onEvent(SlotEvent event) {
    if (_disposed || !mounted) return;
    if (event.position != SlotPosition.current) return;

    final slot = widget.pool.slotFor(SlotPosition.current);
    if (slot == null) return;

    // Epoch guard — drop stale events from a superseded join attempt.
    if (event.epoch != slot.epoch) return;

    // Channel guard — confirm this slot is actually for our stream.
    if (slot.channelId != widget.channelId) return;

    switch (event.kind) {
      case SlotEventKind.joined:
        slot.engine
            .setRemoteDefaultVideoStreamType(VideoStreamType.videoStreamHigh)
            .catchError((_) {});
        if (slot.hostUid.value != null) _buildControllerOnce(slot);

      case SlotEventKind.hostUidReady:
        _buildControllerOnce(slot);

      case SlotEventKind.videoReady:
        if (_controllerEpoch != slot.epoch ||
            _controllerUid != slot.hostUid.value) {
          _buildControllerOnce(slot);
        }
        if (mounted) setState(() => _hasVideo = true);

      case SlotEventKind.leftChannel:
      case SlotEventKind.joinFailed:
        _disposeController();
        if (mounted) setState(() => _hasVideo = false);

      case SlotEventKind.joining:
        break;
    }
  }

  void _buildControllerOnce(EngineSlot slot) {
    final hostUid = slot.hostUid.value;
    if (hostUid == null) return;

    if (_controllerEpoch == slot.epoch &&
        _controllerUid == hostUid &&
        _controller != null) {
      return;
    }

    _disposeController();

    try {
      final controller = VideoViewController.remote(
        rtcEngine: slot.engine,
        useFlutterTexture: true,
        canvas: VideoCanvas(uid: hostUid),
        connection: RtcConnection(channelId: widget.channelId),
      );

      _controllerEpoch = slot.epoch;
      _controllerUid = hostUid;

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
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _controllerEpoch = null;
    _controllerUid = null;
  }

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
          AgoraVideoView(
            key: ValueKey(
              'pool_${widget.channelId}_${_controllerEpoch}_$_controllerUid',
            ),
            controller: _controller!,
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
