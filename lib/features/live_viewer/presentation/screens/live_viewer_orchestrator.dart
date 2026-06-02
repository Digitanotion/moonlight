// lib/features/live_viewer/presentation/screens/live_viewer_orchestrator.dart
//
// CHANGES vs original (minimal — two additions only):
//   1. Optional `onVideoReady` callback parameter added to the widget.
//   2. _OrchestratorState listens to AgoraViewerService.hostHasVideo
//      (the ValueNotifier fired by onRemoteVideoStateChanged in
//      AgoraViewerService) and calls onVideoReady() once — when the
//      first video frame arrives.
//
// Everything else — AnimatedSwitcher, mode switching, sub-screens — is
// identical to the original.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/screens/guest_mode_screen.dart';
import 'package:moonlight/features/live_viewer/presentation/screens/viewer_mode_screen.dart';

/// Main coordinator that switches between viewer and guest modes.
class LiveViewerOrchestrator extends StatefulWidget {
  final ViewerRepositoryImpl repository;

  /// Called exactly once when the first remote video frame is decoded.
  /// Used by LiveViewerScreen to fade out the loading placeholder.
  final VoidCallback? onVideoReady;

  const LiveViewerOrchestrator({
    super.key,
    required this.repository,
    this.onVideoReady, // ← NEW (optional — safe to omit)
  });

  @override
  State<LiveViewerOrchestrator> createState() => _LiveViewerOrchestratorState();
}

class _LiveViewerOrchestratorState extends State<LiveViewerOrchestrator> {
  bool _videoReadyFired = false;

  @override
  void initState() {
    super.initState();
    // AgoraViewerService.hostHasVideo is the ValueNotifier<bool> that is set
    // to true inside onRemoteVideoStateChanged when the host's video starts
    // decoding. We listen to it directly — no ChangeNotifier needed.
    try {
      sl<AgoraViewerService>().hostHasVideo.addListener(_onHostVideoChanged);
    } catch (e) {
      debugPrint(
        '⚠️ [Orchestrator] Could not attach hostHasVideo listener: $e',
      );
    }
  }

  void _onHostVideoChanged() {
    if (_videoReadyFired) return;
    if (!mounted) return;
    try {
      if (sl<AgoraViewerService>().hostHasVideo.value) {
        _videoReadyFired = true;
        debugPrint('🎬 [Orchestrator] Host video ready — fading placeholder');
        widget.onVideoReady?.call();
        // Detach — only need this once
        sl<AgoraViewerService>().hostHasVideo.removeListener(
          _onHostVideoChanged,
        );
      }
    } catch (e) {
      debugPrint('⚠️ [Orchestrator] _onHostVideoChanged error: $e');
    }
  }

  @override
  void dispose() {
    try {
      sl<AgoraViewerService>().hostHasVideo.removeListener(_onHostVideoChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
      // identical buildWhen to original
      buildWhen: (previous, current) => previous.viewMode != current.viewMode,
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildScreenForMode(state.viewMode),
        );
      },
    );
  }

  Widget _buildScreenForMode(ViewMode mode) {
    // identical to original
    return switch (mode) {
      ViewMode.viewer => ViewerModeScreen(
        key: const ValueKey('viewer_mode'),
        repository: widget.repository,
      ),
      ViewMode.guest || ViewMode.cohost => GuestModeScreen(
        key: const ValueKey('guest_mode'),
        repository: widget.repository,
      ),
    };
  }
}
