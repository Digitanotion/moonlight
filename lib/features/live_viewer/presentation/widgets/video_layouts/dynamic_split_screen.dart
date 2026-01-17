// lib/features/live_viewer/presentation/widgets/video_layouts/dynamic_split_screen.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';

/// Dynamic split screen that handles:
/// - Current user is guest: Host + Local Preview
/// - Current user is viewer: Host + Remote Guest Video
class DynamicSplitScreen extends StatelessWidget {
  final ViewerRepositoryImpl repository;
  final bool isCurrentUserGuest;

  const DynamicSplitScreen({
    super.key,
    required this.repository,
    required this.isCurrentUserGuest,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final videoHeight = screenHeight / 2;
    final agoraService = sl<AgoraViewerService>();

    return Stack(
      children: [
        // Top half - ALWAYS Host video
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: videoHeight,
          child: _buildVideoSection(
            videoWidget: agoraService.buildHostVideo(),
            label: 'HOST',
            isHost: true,
          ),
        ),

        // Bottom half - DYNAMIC based on user role
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: videoHeight,
          child: _buildBottomHalf(agoraService),
        ),

        // Divider line
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
      // Current user IS the guest: Show local preview
      return _buildVideoSection(
        videoWidget:
            agoraService.buildLocalPreview() ??
            _buildVideoPlaceholder('YOU (GUEST)'),
        label: 'YOU (GUEST)',
        isHost: false,
      );
    } else {
      // Current user is VIEWER: Show remote guest video
      return _buildVideoSection(
        videoWidget:
            agoraService.buildGuestVideo() ?? _buildVideoPlaceholder('GUEST'),
        label: 'GUEST',
        isHost: false,
      );
    }
  }

  Widget _buildVideoSection({
    required Widget? videoWidget,
    required String label,
    bool isHost = false,
  }) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          videoWidget ?? _buildVideoPlaceholder(label),
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
