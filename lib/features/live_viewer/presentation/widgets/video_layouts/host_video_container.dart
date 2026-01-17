// lib/features/live_viewer/presentation/widgets/video_layouts/host_video_container.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';

// In HostVideoContainer - UPDATED VERSION
class HostVideoContainer extends StatelessWidget {
  final ViewerRepositoryImpl repository;

  const HostVideoContainer({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final agoraService = sl<AgoraViewerService>();

    return ValueListenableBuilder<int?>(
      valueListenable: agoraService.hostUid,
      builder: (context, hostUid, child) {
        if (hostUid == null) {
          // Show loading/connecting state
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Connecting to live stream...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        // Host UID is available, show video
        return agoraService.buildHostVideo();
      },
    );
  }
}
