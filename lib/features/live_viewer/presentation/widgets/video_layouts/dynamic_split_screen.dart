// lib/features/live_viewer/presentation/widgets/video_layouts/dynamic_split_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/pool_video_view.dart';

class DynamicSplitScreen extends StatelessWidget {
  final ViewerRepositoryImpl repository;
  final bool isCurrentUserGuest;
  final AgoraEnginePool? pool;
  final String? channelId;

  const DynamicSplitScreen({
    super.key,
    required this.repository,
    required this.isCurrentUserGuest,
    this.pool,
    this.channelId,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final videoHeight = screenHeight / 2;
    final agoraService = sl<AgoraViewerService>();

    return Stack(
      children: [
        // ── Top half — host video ────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: videoHeight,
          child: _buildVideoSection(
            videoWidget: (pool != null && channelId != null)
                ? PoolVideoView(pool: pool!, channelId: channelId!)
                : agoraService.buildHostVideo(),
            label: 'HOST',
            isHost: true,
          ),
        ),

        // ── Bottom half — dynamic based on user role ─────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: videoHeight,
          child: _buildBottomHalf(agoraService),
        ),

        // Divider
        Positioned(
          top: videoHeight - 1,
          left: 0,
          right: 0,
          child: Container(height: 2, color: Colors.white.withOpacity(0.3)),
        ),
      ],
    );
  }

  Widget _buildBottomHalf(AgoraViewerService agoraService) {
    if (isCurrentUserGuest) {
      // Current user IS the guest: show local camera preview + mic/cam
      // status overlays that react to the guest's own mute state.
      return _GuestLocalPreview(agoraService: agoraService);
    } else {
      // Current user is a viewer watching someone else as guest:
      // show the remote guest video + their mic/cam status.
      return _buildVideoSection(
        videoWidget: agoraService.buildGuestVideo() ??
            _buildVideoPlaceholder('GUEST'),
        label: 'GUEST',
        isHost: false,
        // Non-guest viewers see the guest's mute status via guestHasVideo
        // and the _guestHasVideo notifier on AgoraViewerService.
        mutedCamNotifier: agoraService.guestHasVideo,
        invertCamMuted: true, // hasVideo=false means cam is muted
      );
    }
  }

  Widget _buildVideoSection({
    required Widget? videoWidget,
    required String label,
    bool isHost = false,
    ValueListenable<bool>? mutedCamNotifier,
    bool invertCamMuted = false,
  }) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          videoWidget ?? _buildVideoPlaceholder(label),
          // Role label
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isHost ? Colors.orange : Colors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Optional cam-muted overlay for remote guest
          if (mutedCamNotifier != null)
            ValueListenableBuilder<bool>(
              valueListenable: mutedCamNotifier,
              builder: (_, value, __) {
                final isMuted = invertCamMuted ? !value : value;
                if (!isMuted) return const SizedBox.shrink();
                return Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.videocam_off,
                      color: Colors.white54,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder(String label) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 48, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const Text(
              'Video loading...',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Guest local preview with reactive mic/cam status overlays ─────────────
//
// This is a StatefulWidget so it can listen to AgoraViewerService
// and rebuild only the overlay icons — never the AgoraVideoView itself.

class _GuestLocalPreview extends StatefulWidget {
  final AgoraViewerService agoraService;
  const _GuestLocalPreview({required this.agoraService});

  @override
  State<_GuestLocalPreview> createState() => _GuestLocalPreviewState();
}

class _GuestLocalPreviewState extends State<_GuestLocalPreview> {
  late bool _micMuted;
  late bool _camMuted;

  @override
  void initState() {
    super.initState();
    _micMuted = widget.agoraService.isMicMuted;
    _camMuted = widget.agoraService.isCamMuted;
    widget.agoraService.addListener(_onAgoraChanged);
  }

  @override
  void dispose() {
    widget.agoraService.removeListener(_onAgoraChanged);
    super.dispose();
  }

  void _onAgoraChanged() {
    final newMic = widget.agoraService.isMicMuted;
    final newCam = widget.agoraService.isCamMuted;
    if (newMic != _micMuted || newCam != _camMuted) {
      setState(() {
        _micMuted = newMic;
        _camMuted = newCam;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.agoraService.buildLocalPreview();

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera feed — always in tree, never rebuilt on mute toggle.
          // When cam is muted Agora renders black frames automatically.
          if (preview != null) preview,

          // Role label
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'YOU (GUEST)',
                style: TextStyle(
                  color: Colors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Camera-off overlay — shows when cam is muted.
          if (_camMuted)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off, color: Colors.white54, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Camera off',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // Mic status badge — bottom-right corner.
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _micMuted ? Icons.mic_off : Icons.mic,
                color: _micMuted ? Colors.redAccent : Colors.greenAccent,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}