// lib/features/live_viewer/presentation/widgets/pool_video_view.dart
//
// Updated for RtcEngineEx architecture: slot.engine no longer exists
// (there is only one shared engine on the pool). We now use:
//   - pool.sharedEngine  →  the single RtcEngineEx
//   - slot.connection    →  RtcConnection(channelId, fixedLocalUid)
//   - VideoViewController.remote(..., connection: slot.connection)

import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';

class PoolVideoView extends StatefulWidget {
  const PoolVideoView({
    super.key,
    required this.pool,
    required this.channelId,
  });

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

    // In co-host mode the pool slot was left — fall back to the co-host
    // connection which still receives the host's video.
    final viewerService = sl<AgoraViewerService>();
    if (slot.channelId != widget.channelId ||
        slot.state == SlotJoinState.idle ||
        slot.state == SlotJoinState.unavailable) {
      if (viewerService.isCoHostActive) {
        _buildControllerFromCoHostConnection(viewerService);
      }
      return;
    }

    if ((slot.state == SlotJoinState.joined ||
            slot.state == SlotJoinState.joining) &&
        slot.hostUid.value != null) {
      _buildControllerOnce(slot);
    }

    if (slot.hasVideo.value && mounted) {
      setState(() => _hasVideo = true);
    }
  }

  void _buildControllerFromCoHostConnection(AgoraViewerService viewerService) {
    final conn = viewerService.coHostConnection;
    final hostUid = widget.pool.slotFor(SlotPosition.current)?.hostUid.value;
    if (conn == null || hostUid == null) return;
    if (_controller != null) return; // already built

    try {
      final controller = VideoViewController.remote(
        rtcEngine: widget.pool.sharedEngine,
        useFlutterTexture: true,
        canvas: VideoCanvas(uid: hostUid),
        connection: conn,
      );
      if (mounted) {
        setState(() {
          _controller = controller;
          _hasVideo = true;
        });
      } else {
        _controller = controller;
      }
      debugPrint('🎬 [PoolVideoView] Using co-host connection for host video');
    } catch (e) {
      debugPrint('❌ [PoolVideoView] Co-host controller build failed: \$e');
    }
  }

  void _onEvent(SlotEvent event) {
    if (_disposed || !mounted) return;
    if (event.position != SlotPosition.current) return;

    final slot = widget.pool.slotFor(SlotPosition.current);
    if (slot == null) return;
    if (event.epoch != slot.epoch) return;
    if (slot.channelId != widget.channelId) return;

    switch (event.kind) {
      case SlotEventKind.joined:
        final conn = slot.connection;
        if (conn != null && slot.hostUid.value != null) {
          widget.pool.sharedEngine
              .setRemoteVideoStreamTypeEx(
                uid: slot.hostUid.value!,
                streamType: VideoStreamType.videoStreamHigh,
                connection: conn,
              )
              .catchError((_) {});
        }
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
        // Check if we left because of co-host promotion — if so,
        // build a controller from the co-host connection instead.
        final viewerService = sl<AgoraViewerService>();
        if (viewerService.isCoHostActive) {
          _buildControllerFromCoHostConnection(viewerService);
        } else if (mounted) {
          setState(() => _hasVideo = false);
        }

      case SlotEventKind.joining:
        break;
    }
  }

  void _buildControllerOnce(EngineSlot slot) {
    final hostUid = slot.hostUid.value;
    if (hostUid == null) return;

    final connection = slot.connection;
    if (connection == null) return;

    if (_controllerEpoch == slot.epoch &&
        _controllerUid == hostUid &&
        _controller != null) {
      return;
    }

    _disposeController();

    try {
      final controller = VideoViewController.remote(
        rtcEngine: widget.pool.sharedEngine,
        useFlutterTexture: true,
        canvas: VideoCanvas(uid: hostUid),
        connection: connection,
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