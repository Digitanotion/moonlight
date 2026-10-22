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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/wakelock_coordinator.dart';
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
    this.pool, // ← NEW
    this.channelId, // ← NEW
  });

  @override
  State<LiveViewerOrchestrator> createState() => _LiveViewerOrchestratorState();
}

class _LiveViewerOrchestratorState extends State<LiveViewerOrchestrator> {
  bool _videoReadyFired = false;
  StreamSubscription<SlotEvent>? _poolSub;
  Timer? _readyTicker;

  @override
  void initState() {
    super.initState();
    // Held for the whole viewing session (viewer <-> guest/cohost mode
    // switches never tear this widget down, only the child it builds), so
    // the screen doesn't sleep mid-stream regardless of which mode is active.
    WakelockCoordinator.instance.acquire();
    if (widget.pool != null) {
      // Pool mode: listen to the pool's events stream for videoReady.
      // The old hostHasVideo listener on the AgoraViewerService singleton
      // is NOT attached — in pool mode the singleton isn't the engine
      // serving this stream.
      //
      // The video can be ready BEFORE this widget exists (pre-joined slot,
      // fast connect) — then the one-off videoReady event is already gone
      // and the "Joining…" cover used to stay forever. So also look at the
      // slot's real state now and every half second until it's up.
      _poolSub = widget.pool!.events.listen(_onPoolEvent);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkPoolReady());
      _readyTicker = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _checkPoolReady(),
      );
    } else {
      // Original path: listen to the singleton AgoraViewerService.
      try {
        sl<AgoraViewerService>().hostHasVideo.addListener(_onHostVideoChanged);
        // Already playing before we started listening?
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _onHostVideoChanged(),
        );
      } catch (e) {
        debugPrint('⚠️ [Orchestrator] hostHasVideo listener failed: $e');
      }
    }
  }

  /// Fire once the current slot is OUR stream and the host's video is on.
  void _checkPoolReady() {
    if (_videoReadyFired || !mounted) {
      _readyTicker?.cancel();
      return;
    }
    final slot = widget.pool!.slotFor(SlotPosition.current);
    if (slot == null || slot.channelId != widget.channelId) return;
    if (!slot.hasVideo.value) return;
    _videoReadyFired = true;
    _readyTicker?.cancel();
    debugPrint('🎬 [Orchestrator/pool] video on for ${widget.channelId}');
    widget.onVideoReady?.call();
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
    debugPrint(
      '🎬 [Orchestrator/pool] first frame ready on ${widget.channelId}',
    );
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
    _poolSub?.cancel();
    _readyTicker?.cancel();
    WakelockCoordinator.instance.release();
    if (widget.pool == null) {
      try {
        sl<AgoraViewerService>().hostHasVideo.removeListener(
          _onHostVideoChanged,
        );
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
