// lib/features/live_viewer/presentation/screens/live_viewer_orchestrator.dart
//
// REPLACEMENT. Two additions only vs the original:
//   1. Accepts optional `pool` and `channelId`.
//   2. When both are present, builds the host video via PoolVideoView
//      (slot-aware, pre-joined engine) instead of AgoraViewerService
//      .buildHostVideo() (singleton engine). ALL other logic —
//      AnimatedSwitcher, ViewMode switching, GuestModeScreen,
//      ViewerModeScreen, the onVideoReady callback — is unchanged.
//
// The old AgoraViewerService.buildHostVideo() path is still used when
// pool is null (standalone stream opens, host screen, etc.).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/screens/guest_mode_screen.dart';
import 'package:moonlight/features/live_viewer/presentation/screens/viewer_mode_screen.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/pool_video_view.dart';

class LiveViewerOrchestrator extends StatefulWidget {
  final ViewerRepositoryImpl repository;
  final VoidCallback? onVideoReady;

  // ── NEW optional pool params ─────────────────────────────────────────
  final AgoraEnginePool? pool;
  final String? channelId;

  const LiveViewerOrchestrator({
    super.key,
    required this.repository,
    this.onVideoReady,
    this.pool,       // ← NEW
    this.channelId,  // ← NEW
  });

  @override
  State<LiveViewerOrchestrator> createState() => _LiveViewerOrchestratorState();
}

class _LiveViewerOrchestratorState extends State<LiveViewerOrchestrator> {
  bool _videoReadyFired = false;

  @override
  void initState() {
    super.initState();
    if (widget.pool != null) {
      // Pool mode: listen to the pool's events stream for videoReady.
      // The old hostHasVideo listener on the AgoraViewerService singleton
      // is NOT attached — in pool mode the singleton isn't the engine
      // serving this stream.
      widget.pool!.events.listen(_onPoolEvent);
    } else {
      // Original path: listen to the singleton AgoraViewerService.
      try {
        sl<AgoraViewerService>().hostHasVideo.addListener(_onHostVideoChanged);
      } catch (e) {
        debugPrint('⚠️ [Orchestrator] hostHasVideo listener failed: $e');
      }
    }
  }

  void _onPoolEvent(SlotEvent event) {
    if (_videoReadyFired) return;
    if (!mounted) return;
    if (event.position != SlotPosition.current) return;
    if (event.kind != SlotEventKind.videoReady) return;

    // Epoch guard: confirm the event belongs to the current slot's
    // live join attempt, not a stale one from a previously rotated stream.
    final slot = widget.pool!.slotFor(SlotPosition.current);
    if (slot == null) return;
    if (event.epoch != slot.epoch) return;
    if (slot.channelId != widget.channelId) return;

    _videoReadyFired = true;
    debugPrint('🎬 [Orchestrator/pool] first frame ready on ${widget.channelId}');
    widget.onVideoReady?.call();
  }

  void _onHostVideoChanged() {
    // Original single-engine path (unchanged).
    if (_videoReadyFired) return;
    if (!mounted) return;
    try {
      if (sl<AgoraViewerService>().hostHasVideo.value) {
        _videoReadyFired = true;
        debugPrint('🎬 [Orchestrator] Host video ready — fading placeholder');
        widget.onVideoReady?.call();
        sl<AgoraViewerService>().hostHasVideo.removeListener(_onHostVideoChanged);
      }
    } catch (e) {
      debugPrint('⚠️ [Orchestrator] _onHostVideoChanged error: $e');
    }
  }

  @override
  void dispose() {
    if (widget.pool == null) {
      try {
        sl<AgoraViewerService>().hostHasVideo.removeListener(_onHostVideoChanged);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ViewerBloc, ViewerState>(
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
    return switch (mode) {
      ViewMode.viewer => ViewerModeScreen(
        key: const ValueKey('viewer_mode'),
        repository: widget.repository,
        // Pass pool/channelId so ViewerModeScreen can render PoolVideoView.
        pool: widget.pool,
        channelId: widget.channelId,
      ),
      ViewMode.guest || ViewMode.cohost => GuestModeScreen(
        key: const ValueKey('guest_mode'),
        repository: widget.repository,
        // Pass pool/channelId so the TOP half (host video) can render
        // from the pool's current slot — same engine already showing
        // the host in viewer mode, before promotion.
        pool: widget.pool,
        channelId: widget.channelId,
      ),
    };
  }
}