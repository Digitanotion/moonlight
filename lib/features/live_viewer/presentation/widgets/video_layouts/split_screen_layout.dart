// lib/features/live_viewer/presentation/widgets/video_layouts/split_screen_layout.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';

class SplitScreenLayout extends StatelessWidget {
  final ViewerRepositoryImpl repository;
  final LiveStreamService? liveStreamService;

  const SplitScreenLayout({
    super.key,
    required this.repository,
    this.liveStreamService,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final videoHeight = screenHeight / 2;
    final agoraService = sl<AgoraViewerService>();

    return BlocBuilder<ViewerBloc, ViewerState>(
      buildWhen: (p, n) => p.viewMode != n.viewMode,
      builder: (context, state) {
        if (state.viewMode != ViewMode.guest &&
            state.viewMode != ViewMode.cohost) {
          return Container(color: Colors.black);
        }

        return Stack(
          children: [
            // Top half - Host video
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

            // Bottom half - Local preview (guest)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: videoHeight,
              child: _buildVideoSection(
                videoWidget:
                    agoraService.buildLocalPreview() ??
                    _buildVideoPlaceholder('YOU (GUEST)'),
                label: 'YOU (GUEST)',
                isHost: false,
              ),
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
      },
    );
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
                style: const TextStyle(
                  color: Colors.white,
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
