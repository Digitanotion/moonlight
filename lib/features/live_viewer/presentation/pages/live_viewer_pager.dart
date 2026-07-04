// lib/features/live_viewer/presentation/pages/live_viewer_pager.dart
//
// REPLACEMENT. The pager now owns the AgoraEnginePool and is the single
// orchestrator of "which engine is joined to which stream."
//
// Key changes vs original:
//   1. Owns an AgoraEnginePool (3 engines, created once on initState).
//   2. Owns a PoolRtcResolver (translates index → StreamJoinRequest via
//      your /rtc HTTP endpoint).
//   3. _onPageScrolled now calls pool.rotate() whenever the settled page
//      changes — instead of repo.prefetchRtcToken() + repo.resetWiring().
//   4. Implements WidgetsBindingObserver for app-lifecycle pool pause/
//      resume (backgrounded → releases non-current engines to save
//      battery; foregrounded → rejoins them).
//   5. Passes `pool` and the stream's channelId down to each page via
//      LiveViewerScreen so it can render PoolVideoView instead of the
//      old AgoraViewerService.buildHostVideo() widget.
//   6. The existing ViewerRepositoryImpl repos are RETAINED for all
//      non-video concerns: Pusher chat/gifts/events, /enter, /leave,
//      status checks, health polling, BLoC state. Only the Agora
//      join/leave/render is now handled by the pool. The repos no longer
//      call agoraViewerService.joinAudience() — that call is suppressed
//      in a thin flag we set on the repo (see ViewerRepositoryImpl
//      changes below).
//
// NOTHING ELSE CHANGES. The BLoC, ViewerState, event handlers, chat,
// gifts, premium paywall, role changes, and all overlay logic remain
// exactly as they were.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';
import 'package:moonlight/features/live_viewer/presentation/widgets/pool_video_view.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';
import 'package:moonlight/features/live_viewer/data/pool_rtc_resolver.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart' show HostInfo;
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/live_viewer_screen.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/network_monitor_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/reconnection_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/role_change_service.dart';

class LiveViewerPager extends StatefulWidget {
  final List<LiveItem> items;
  final int initialIndex;
  final List<Map<String, dynamic>>? allArgs;

  const LiveViewerPager({
    super.key,
    required this.items,
    required this.initialIndex,
    this.allArgs,
  });

  @override
  State<LiveViewerPager> createState() => _LiveViewerPagerState();
}

class _LiveViewerPagerState extends State<LiveViewerPager>
    with WidgetsBindingObserver {
  late final PageController _controller;
  late final List<ViewerRepositoryImpl> _repos;

  // ── Pool and resolver ────────────────────────────────────────────────
  late final AgoraEnginePool _pool;
  late final PoolRtcResolver _resolver;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _currentPage = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);

    // Build repos (still needed for all non-Agora concerns).
    _repos = widget.items.asMap().entries.map((e) {
      return _makeRepoForItem(e.value);
    }).toList();

    // keepAlive=true: soft dispose on page swipe keeps Pusher wiring
    // alive between swipes — no change from the original behavior.
    for (final repo in _repos) {
      repo.keepAlive = true;
      // Tell each repo NOT to call joinAudience() in _wireInternal().
      // The pool now owns all Agora join/leave; repos only handle
      // Pusher/chat/events/health/HTTP concerns.
      repo.skipAgoraJoin = true;
    }

    // Pool is now a GetIt singleton registered in injection_container.dart.
    // Do NOT create a new one here — it owns the shared RtcEngineEx, and
    // only one engine may exist per app. The singleton is shared with
    // AgoraViewerService (which also holds a reference to it for co-host
    // publish via the same engine).
    _pool = sl<AgoraEnginePool>();
    _resolver = PoolRtcResolver(http: sl<DioClient>());

    _controller.addListener(_onPageScrolled);

    // Initialize pool + join initial window after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final wasAlreadyInitialized = _pool.isInitialized;
      await _pool.initialize();

      // Wire guest uid propagation before setInitialWindow.
      _pool.setGuestUidCallback((guestUid) {
        sl<AgoraViewerService>().setGuestUid(guestUid);
      });

      // Always (re)set the initial window. This triggers _ensureEngineContext
      // which initializes the native engine context — handler registration
      // MUST happen after this, not before, to avoid a double-initialize.
      await _pool.setInitialWindow(
        currentIndex: widget.initialIndex,
        itemCount: widget.items.length,
        resolve: (i) => _resolver.resolve(widget.items, i),
      );

      // Register the standalone event handler AFTER setInitialWindow so
      // the engine context is fully initialized before we attach handlers.
      // Registering before _ensureEngineContext causes a second initialize
      // call which resets the engine state and breaks video rendering.
      if (!wasAlreadyInitialized) {
        sl<AgoraViewerService>().registerStandaloneEventHandler();
      }
      // Trigger non-Agora wiring (Pusher/chat/health) for the initial page.
      if (mounted && widget.initialIndex < _repos.length) {
        _repos[widget.initialIndex].ensureWiredOnce();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onPageScrolled);
    _controller.dispose();

    // Hard dispose all repos (Pusher/events cleanup).
    for (final repo in _repos) {
      repo.keepAlive = false;
      try { repo.dispose(); } catch (_) {}
    }

    // Dispose the pool — leaves all channels, releases all 3 engines.
    // The pool is a GetIt singleton — do NOT call disposeAll() here, as
    // that would tear down the shared engine for the whole app lifetime.
    // BUT we must leave all active connections so Agora stops sending
    // audio/video — otherwise streams keep playing after the page closes.
    _pool.leaveAll();
    super.dispose();
  }

  // ── App lifecycle ────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _pool.onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _pool.onAppForegrounded(
        currentIndex: _currentPage,
        itemCount: widget.items.length,
        resolve: (i) => _resolver.resolve(widget.items, i),
      );
    }
  }

  // ── Scroll handling ──────────────────────────────────────────────────

  void _onPageScrolled() {
    if (!_controller.hasClients) return;
    final raw = _controller.page ?? widget.initialIndex.toDouble();
    final nearestPage = raw.round();
    if (nearestPage == _currentPage) return;

    final previousPage = _currentPage;
    _currentPage = nearestPage;

    // Rotate the engine pool — this is what achieves sub-2-second swipes.
    // The call is fire-and-forget from the scroll listener's perspective;
    // the pool's internal serialization queue ensures rapid calls don't
    // pile up or cause overlapping joins.
    _pool.rotate(
      newIndex: nearestPage,
      itemCount: widget.items.length,
      resolve: (i) => _resolver.resolve(widget.items, i),
    );

    // Pre-cache covers for smooth thumbnail loading (unchanged).
    _precacheAdjacentCovers(nearestPage);

    // Manage repo wiring for Pusher/chat/health (unchanged logic from
    // original, but skipAgoraJoin=true means Agora join is suppressed).
    if (nearestPage < previousPage &&
        nearestPage >= 0 &&
        nearestPage < _repos.length) {
      // Swipe back: reset Pusher wiring so ensureWiredOnce re-subscribes.
      final repo = _repos[nearestPage];
      debugPrint('🔄 [Pager] Swipe back to page $nearestPage — resetting wiring');
      repo.resetWiring();
    }

    // Wire the newly-visible page's non-Agora concerns (Pusher/chat/health).
    if (nearestPage >= 0 && nearestPage < _repos.length) {
      _repos[nearestPage].ensureWiredOnce();
    }
  }

  void _precacheAdjacentCovers(int centre) {
    for (final i in [centre - 1, centre, centre + 1]) {
      if (i < 0 || i >= widget.items.length) continue;
      final url = widget.items[i].coverUrl;
      if (url != null && url.isNotEmpty && mounted) {
        precacheImage(NetworkImage(url), context).ignore();
      }
    }
  }

  ViewerRepositoryImpl _makeRepoForItem(LiveItem item) {
    return ViewerRepositoryImpl(
      http: sl<DioClient>(),
      pusher: sl<PusherService>(),
      authLocalDataSource: sl<AuthLocalDataSource>(),
      agoraViewerService: sl<AgoraViewerService>(),
      livestreamParam: item.uuid,
      livestreamIdNumeric: item.id,
      channelName: item.channel,
      hostUserUuid: item.hostUuid,
      initialHost: HostInfo(
        name: item.role,
        title: item.title ?? '',
        subtitle: '',
        badge: item.role,
        avatarUrl: item.coverUrl ?? '',
        isFollowed: item.isFollowed ?? false,
      ),
      startedAt: item.startedAt != null
          ? DateTime.tryParse(item.startedAt!)
          : null,
    );
  }

  Map<String, dynamic> _routeArgsForIndex(int i) {
    if (widget.allArgs != null && widget.allArgs!.length > i) {
      return widget.allArgs![i];
    }
    final item = widget.items[i];
    return {
      'id': item.id,
      'uuid': item.uuid,
      'channel': item.channel,
      'hostUuid': item.hostUuid,
      'hostName': item.handle.replaceFirst('@', ''),
      'hostAvatar': item.coverUrl,
      'title': item.title,
      'startedAt': item.startedAt,
      'role': item.role,
      'isPremium': item.isPremium ?? 0,
      'premiumFee': item.premiumFee ?? 0,
      'livestreamId': item.uuid,
      'livestreamIdNumeric': item.id,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        physics: const PageScrollPhysics(),
        itemCount: widget.items.length,
        itemBuilder: (context, i) {
          final repo = _repos[i];
          final routeArgs = _routeArgsForIndex(i);
          return BlocProvider<ViewerBloc>(
            create: (_) => ViewerBloc(
              repo,
              agoraViewerService: sl<AgoraViewerService>(),
              liveStreamService: sl<LiveStreamService>(),
              networkMonitorService: null,
              reconnectionService: null,
              roleChangeService: sl<RoleChangeService>(),
            ),
            child: LiveViewerScreen(
              repository: repo,
              routeArgs: routeArgs,
              pool: _pool,
              channelId: widget.items[i].channel,
            ),
          );
        },
      ),
    );
  }
}