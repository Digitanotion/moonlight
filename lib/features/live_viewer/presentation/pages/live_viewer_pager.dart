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
import 'package:moonlight/core/services/mini_player_controller.dart';
import 'package:moonlight/core/services/pip_service.dart';
import 'package:moonlight/core/services/screen_guard.dart';
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

  /// Pushed as a **transparent** route: while minimised the pager shrinks to a
  /// small window and the screen underneath shows through and stays usable,
  /// with the viewer's Agora + Pusher state fully alive the whole time.
  static Route<void> route({
    required List<LiveItem> items,
    required int initialIndex,
    List<Map<String, dynamic>>? allArgs,
  }) {
    return _ViewerPagerRoute(
      builder: (_) => LiveViewerPager(
        items: items,
        initialIndex: initialIndex,
        allArgs: allArgs,
      ),
    );
  }

  @override
  State<LiveViewerPager> createState() => _LiveViewerPagerState();
}

class _LiveViewerPagerState extends State<LiveViewerPager>
    with WidgetsBindingObserver {
  // Only one live-viewer session may exist at a time. Opening a new stream
  // (from the grid, a deep link, a notification) closes the previous one so
  // its audio/video and PiP arming don't linger behind the new stream.
  static _LiveViewerPagerState? _active;

  late final PageController _controller;
  late final List<ViewerRepositoryImpl> _repos;

  // ── Pool and resolver ────────────────────────────────────────────────
  late final AgoraEnginePool _pool;
  late final PoolRtcResolver _resolver;

  int _currentPage = 0;

  // ── In-app minimise (draggable window) ──────────────────────────────────
  Offset? _miniOffset; // null = default corner
  static const double _miniW = 116;
  static const double _miniH = 196;

  @override
  void initState() {
    super.initState();

    // Tear down any previous live-viewer session first — deactivates its PiP
    // and background playback so this new stream opens cleanly.
    final previous = _active;
    if (previous != null && previous.mounted) {
      try {
        previous._closeForNewSession();
      } catch (_) {}
    }
    _active = this;

    MiniPlayerController.instance.bindActivePager(_minimizeToMini);
    MiniPlayerController.instance.addListener(_onMiniChanged);

    ScreenGuard.acquire(); // no screenshots / recording while watching
    // Items 9 + 10: keep the stream playing when the app is backgrounded, in
    // an OS Picture-in-Picture window, until the viewer is closed.
    PipService.instance.acquire();
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

  /// Shrink into the draggable in-app window. The route is NOT popped — its
  /// state, Agora connection and Pusher subscriptions all stay live, so
  /// restoring is instant. The route was pushed transparent, so the screen
  /// underneath shows through and stays interactive.
  void _minimizeToMini() {
    if (!mounted) return;
    _miniOffset = null;
    MiniPlayerController.instance.minimize();
  }

  void _onMiniChanged() {
    if (mounted) setState(() {});
  }

  /// Called by a newer pager taking over: leave Agora + pop this route so the
  /// old stream doesn't keep playing behind the new one.
  void _closeForNewSession() {
    try {
      _pool.leaveAll();
    } catch (_) {}
    final nav = Navigator.of(context, rootNavigator: false);
    if (nav.canPop()) nav.pop();
  }

  @override
  void dispose() {
    if (identical(_active, this)) _active = null;
    MiniPlayerController.instance.removeListener(_onMiniChanged);
    MiniPlayerController.instance.unbindActivePager(_minimizeToMini);
    ScreenGuard.release();
    PipService.instance.release();
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onPageScrolled);
    _controller.dispose();

    // Hard dispose all repos (Pusher/events cleanup).
    for (final repo in _repos) {
      // Stop this page's health-check polling BEFORE disposing — dispose()
      // closes the stream this signal travels through, so calling it after
      // would throw. This is the actual fix for streams left orphaned and
      // still polling even after the whole pager (not just one page) is
      // closed — the earlier fix only handled swiping between pages within
      // an active session, never closing the pager entirely.
      try { repo.pauseHealthCheck(); } catch (_) {}
      repo.keepAlive = false;
      try { repo.dispose(); } catch (_) {}
    }

    // Leave all Agora connections so audio/video stops.
    _pool.leaveAll();
    super.dispose();
  }

  // ── App lifecycle ────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // Items 9 + 10: DON'T tear the stream down. Keep the current slot
      // joined so audio + video continue in the PiP window / while the user
      // is in another app; only release the off-screen slots.
      _pool.onAppBackgroundedKeepingCurrent();
      // Health polling can pause though — the payload is only needed for the
      // in-app UI, which isn't visible.
      if (_currentPage >= 0 && _currentPage < _repos.length) {
        try {
          _repos[_currentPage].pauseHealthCheck();
        } catch (_) {}
      }
    } else if (state == AppLifecycleState.resumed) {
      _pool.onAppForegroundedFromPip(
        currentIndex: _currentPage,
        itemCount: widget.items.length,
        resolve: (i) => _resolver.resolve(widget.items, i),
      );
      if (_currentPage >= 0 && _currentPage < _repos.length) {
        try {
          _repos[_currentPage].resumeHealthCheck();
        } catch (_) {}
      }
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
      if (previousPage >= 0 && previousPage < _repos.length && previousPage != nearestPage) {
    _repos[previousPage].pauseHealthCheck();
  }
    // Wire the newly-visible page's non-Agora concerns (Pusher/chat/health).
    if (nearestPage >= 0 && nearestPage < _repos.length) {
      _repos[nearestPage].ensureWiredOnce();
      _repos[nearestPage].resumeHealthCheck();
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

  // ── Seamless wrap-around ─────────────────────────────────────────────
  //
  // When the viewer swipes past the last stream, silently loop back to the
  // first one instead of dead-ending — "so the users will not know that the
  // profiles have finished" (product spec item 15).
  bool _wrapping = false;

  bool _handleScrollNotification(ScrollNotification n) {
    if (_wrapping || widget.items.length < 2) return false;
    final lastIndex = widget.items.length - 1;

    // Overscroll past the bottom edge while sitting on the last page.
    if (n is OverscrollNotification &&
        n.overscroll > 0 &&
        _currentPage >= lastIndex) {
      _wrapping = true;
      // Defer so we don't mutate the controller mid-scroll-notification.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) {
          _wrapping = false;
          return;
        }
        _controller.jumpToPage(0);
        _wrapping = false;
      });
    }
    return false;
  }

  Widget _buildViewerContent() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: PageView.builder(
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
                onPremiumUnlocked: () => _pool.refreshCurrentSlot(
                  () => _resolver.resolve(widget.items, i, forceRefresh: true),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minimized = MiniPlayerController.instance.minimized;
    final media = MediaQuery.of(context);
    final sz = media.size;
    final safe = media.padding;

    // Target geometry: full screen, or the small draggable corner window.
    late final Rect target;
    if (minimized) {
      final maxX = (sz.width - _miniW - 12).clamp(12.0, double.infinity);
      final minY = safe.top + 12;
      final maxY = (sz.height - _miniH - 12 - safe.bottom - 64)
          .clamp(minY, double.infinity);
      final pos = _miniOffset ?? Offset(maxX, maxY);
      final clamped =
          Offset(pos.dx.clamp(12.0, maxX), pos.dy.clamp(minY, maxY));
      target = Rect.fromLTWH(clamped.dx, clamped.dy, _miniW, _miniH);
    } else {
      target = Rect.fromLTWH(0, 0, sz.width, sz.height);
    }

    // IMPORTANT: the viewer tree (Scaffold → PageView → BlocProvider) must
    // stay at the SAME position in the widget tree across minimise/restore,
    // otherwise Flutter tears it down and rebuilds it — which re-creates the
    // ViewerBloc and forces a fresh Agora join (the "overlay stuck / no
    // video on restore" bug). So we ALWAYS render it as children[0] of the
    // same Stack, only animating its rect and toggling a few flags.
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: target.left,
          top: target.top,
          width: target.width,
          height: target.height,
          child: GestureDetector(
            onTap: minimized ? MiniPlayerController.instance.expand : null,
            onPanUpdate: minimized
                ? (d) => setState(() {
                      _miniOffset = (_miniOffset ?? target.topLeft) + d.delta;
                    })
                : null,
            child: Material(
              elevation: minimized ? 14 : 0,
              color: Colors.black,
              borderRadius: BorderRadius.circular(minimized ? 14 : 0),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Same instance/position always — never wrapped/unwrapped.
                  IgnorePointer(
                    ignoring: minimized,
                    child: _buildViewerContent(),
                  ),

                  // Mini-only chrome — added/removed as later siblings, which
                  // does not disturb children[0]'s element.
                  if (minimized) ...[
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 30, minHeight: 30),
                        iconSize: 16,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        onPressed: () {
                          MiniPlayerController.instance.expand();
                          final nav = Navigator.of(context);
                          if (nav.canPop()) nav.pop();
                        },
                      ),
                    ),
                    const Positioned(
                        left: 6, bottom: 6, child: _MiniLiveDot()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Transparent page route for the live-viewer pager.
///
/// A normal [PageRoute] (even a transparent [PageRouteBuilder]) inserts a
/// full-screen [ModalBarrier] whose gesture layer is `HitTestBehavior.opaque`
/// — so it swallows every touch to whatever is below it, dismissible or not.
/// That's why, while the viewer was minimised into its little window, the
/// rest of the app was frozen.
///
/// This route drops the barrier the moment the viewer is minimised (and
/// restores a normal blocking barrier at full screen, so nothing leaks
/// through the transparent route underneath the full-screen viewer). It
/// rebuilds the barrier whenever [MiniPlayerController] toggles.
class _ViewerPagerRoute<T> extends PageRoute<T> {
  _ViewerPagerRoute({required this.builder}) {
    MiniPlayerController.instance.addListener(_onMiniChanged);
  }

  final WidgetBuilder builder;

  void _onMiniChanged() {
    // Rebuilds _modalBarrier via ModalRoute.changedInternalState().
    changedInternalState();
  }

  @override
  void dispose() {
    MiniPlayerController.instance.removeListener(_onMiniChanged);
    super.dispose();
  }

  @override
  bool get opaque => false;
  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => false;
  @override
  String? get barrierLabel => null;
  @override
  bool get maintainState => true;
  @override
  bool get fullscreenDialog => true;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 240);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildModalBarrier() {
    if (MiniPlayerController.instance.minimized) {
      return const SizedBox.shrink(); // let the app behind stay interactive
    }
    return const ModalBarrier(dismissible: false);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );
  }
}

class _MiniLiveDot extends StatelessWidget {
  const _MiniLiveDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.redAccent, size: 7),
          SizedBox(width: 4),
          Text('LIVE',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}