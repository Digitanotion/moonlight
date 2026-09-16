// lib/features/home/presentation/widgets/home_top_tabs.dart
//
// Logo, the Watch/Discover/Video Chat tabs, and the account button all sit
// on ONE line now — this absorbed what used to be the separate HomeAppBar
// row (see home_app_bar.dart for the reusable AccountButton it kept).
//
// Watch and Discover are real, persistent TabBarView pages — swiping
// between them behaves exactly like TikTok's Following/For You, state and
// scroll position both preserved. Video Chat is different in kind (it's an
// action flow — start a call — not a feed to browse), and that screen owns
// a full Scaffold/AppBar of its own; duplicating that under this header
// would look wrong and risks touching a screen that already works.
// Swiping/tapping to it instead pushes the exact same unmodified route the
// old header pill used to, then the tab springs back to whichever feed you
// were on — same destination, same behavior, just reached by swipe now.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/unread_badge_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/widgets/about_moonlight_sheet.dart';
import 'package:moonlight/core/widgets/update_progress_ring.dart';
import 'package:moonlight/features/feed/domain/repositories/feed_repository.dart';
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/feed/presentation/pages/feed_screen.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_bloc.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_event.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_state.dart';
import 'package:moonlight/features/home/presentation/widgets/home_app_bar.dart';
import 'package:moonlight/features/home/presentation/widgets/home_discover_grid.dart';

class HomeTopTabs extends StatefulWidget {
  const HomeTopTabs({super.key});

  @override
  State<HomeTopTabs> createState() => _HomeTopTabsState();
}

class _HomeTopTabsState extends State<HomeTopTabs>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _videoChatTabIndex = 2;

  late final TabController _tabs = TabController(length: 3, vsync: this);
  late final FeedCubit _discoverCubit = sl<FeedCubit>()..loadFirstPage();
  // Owned here (not inside HomeDiscoverGrid) for the same reason as
  // _discoverCubit: starts loading the moment Home mounts, and lets the
  // tab bar's re-tap handler trigger a refresh on it directly.
  late final FeedCubit _watchVideoCubit = FeedCubit(
    sl<FeedRepository>(),
    type: 'video',
    sort: 'trending',
  )..loadFirstPage();
  late final UnreadBadgeService _unreadService;
  Timer? _pollTimer;

  int _lastRealIndex = 0; // Watch or Discover — never Video Chat
  bool _navigating = false;
  bool _watchRefreshing = false;
  bool _discoverRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChange);
    // Force both feed cubits to start loading right now, rather than
    // leaning on the incidental timing of a `late final` field's first
    // read (which happened to work via the TabBarView children list, but
    // shouldn't be relied on) — this is what makes Discover (and Watch's
    // videos) genuinely preloaded before the user ever swipes to them.
    _discoverCubit;
    _watchVideoCubit;

    WidgetsBinding.instance.addObserver(this);
    _unreadService = GetIt.instance<UnreadBadgeService>();
    _initUnreadService();
  }

  Future<void> _initUnreadService() async {
    try {
      await _unreadService.initialize();
      _unreadService.messageUnreadCount.addListener(_refreshUnread);
      _unreadService.notificationUnreadCount.addListener(_refreshUnread);
      _refreshUnread();
      _startPoll();
    } catch (e) {
      debugPrint('HomeTopTabs: Error initializing unread service: $e');
    }
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _unreadService.refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pollTimer == null) _startPoll();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _refreshUnread() {
    if (mounted) setState(() {});
  }

  // TabController.indexIsChanging is only true for a tap-triggered
  // animateTo() — a user *swipe* settling on a page sets .index directly,
  // which never flips indexIsChanging. Gating on that flag was the exact
  // bug behind "swiping to Video Chat shows nothing": the listener always
  // bailed out early for swipes. Just react to the index itself instead.
  void _onTabChange() {
    if (_tabs.index != _videoChatTabIndex) {
      _lastRealIndex = _tabs.index;
      return;
    }
    if (_navigating) return;
    _navigating = true;
    Navigator.of(context).pushNamed(RouteNames.videoCallDirectory).then((_) {
      _navigating = false;
      if (mounted) _tabs.animateTo(_lastRealIndex);
    });
  }

  // TabBar's onTap fires on every tap, including one on the tab that's
  // already selected — unlike the TabController listener above, which only
  // reacts to an actual index change. That's exactly what distinguishes
  // "switching to this tab" (no reload — it should already be preloaded)
  // from "re-tapping the tab I'm already on" (reload from the beginning).
  Future<void> _onTabTap(int index) async {
    if (index != _tabs.index) return;
    if (index == 0) {
      if (_watchRefreshing) return;
      setState(() => _watchRefreshing = true);
      context.read<LiveFeedBloc>().add(LiveFeedRefresh());
      await _watchVideoCubit.refresh();
      if (mounted) setState(() => _watchRefreshing = false);
    } else if (index == 1) {
      if (_discoverRefreshing) return;
      setState(() => _discoverRefreshing = true);
      await _discoverCubit.refresh();
      if (mounted) setState(() => _discoverRefreshing = false);
    }
  }

  Future<void> _navigateToNotification() async {
    await Navigator.pushNamed(context, RouteNames.notifications);
    _unreadService.refresh();
  }

  Future<void> _navigateToConversations() async {
    await Navigator.pushNamed(context, RouteNames.conversations);
    _unreadService.refresh();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChange);
    _tabs.dispose();
    _discoverCubit.close();
    _watchVideoCubit.close();
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _unreadService.messageUnreadCount.removeListener(_refreshUnread);
    _unreadService.notificationUnreadCount.removeListener(_refreshUnread);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                UpdateProgressRing(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showAboutMoonlightSheet(context),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 20,
                      height: 32,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: BlocBuilder<LiveFeedBloc, LiveFeedState>(
                    buildWhen: (p, n) => p.items.isEmpty != n.items.isEmpty,
                    builder: (context, liveState) {
                      final hasLive = liveState.items.isNotEmpty;
                      return TabBar(
                        controller: _tabs,
                        onTap: _onTabTap,
                        isScrollable: true,
                        padding: EdgeInsets.zero,
                        tabAlignment: TabAlignment.start,
                        indicatorSize: TabBarIndicatorSize.label,
                        indicatorColor: AppColors.primary_,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white38,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        tabs: [
                          // Fixed-width trailing slot on Watch/Discover — the
                          // live badge and the refreshing dot each mount and
                          // unmount as their state flips, and doing that
                          // inside a plain Row changed the Row's (and so the
                          // Tab's) intrinsic width, visibly shoving every
                          // tab after it sideways. Reserving the space up
                          // front, always present whether or not anything
                          // is drawn in it, keeps every tab's width — and
                          // therefore every tab's position — constant.
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Watch'),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 38,
                                  height: 18,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _watchRefreshing
                                        ? const _RefreshingDot()
                                        : hasLive
                                        ? const _LiveBadge()
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Discover'),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _discoverRefreshing
                                        ? const _RefreshingDot()
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Tab(text: 'Video Calls'),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                AccountButton(
                  notificationCount:
                      _unreadService.notificationUnreadCount.value,
                  messageCount: _unreadService.messageUnreadCount.value,
                  onOpenNotifications: _navigateToNotification,
                  onOpenMessages: _navigateToConversations,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Dismissible nudge, not a persistent bar — sits right under the
          // header, out of the floating bottom nav's way entirely.
          //const EarnCashBanner(),
          // Background-update heads-up — only ever visible while
          // AutoUpdateService actually has something to report.
          const UpdateStatusBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                HomeDiscoverGrid(videoCubit: _watchVideoCubit),
                BlocProvider.value(
                  value: _discoverCubit,
                  child: const FeedBody(showAppBar: false),
                ),
                // Never actually seen — _onTabChange snaps back to the
                // last real tab before this one settles into view.
                const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small dot next to a tab's label that grows and glows in a continuous
/// pulse — the "refresh is happening" cue for the re-tap-to-refresh
/// gesture, since the tab's own content swap (shimmer → data) can be too
/// quick/subtle to notice on a fast connection.
class _RefreshingDot extends StatefulWidget {
  const _RefreshingDot();

  @override
  State<_RefreshingDot> createState() => _RefreshingDotState();
}

class _RefreshingDotState extends State<_RefreshingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final scale = 0.75 + t * 1.0; // grows and shrinks
        final glow = 3.0 + t * 9.0; // glows in step with the growth
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.85),
                  blurRadius: glow,
                  spreadRadius: glow * 0.25,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small red "LIVE" pill shown next to the Watch tab's label whenever at
/// least one live stream is currently up.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE53935),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
        // Perched on the badge's top-right corner, outside its own bounds
        // (Stack's clipBehavior: none lets it paint there without nudging
        // the badge's own layout size — same trick as the refreshing dot).
        const Positioned(top: -5, right: -5, child: _DancingLiveIcon()),
      ],
    );
  }
}

/// Small live-tv glyph that wiggles and glows in a continuous loop —
/// perched on the LIVE badge's corner for a bit of life instead of a
/// static pill.
class _DancingLiveIcon extends StatefulWidget {
  const _DancingLiveIcon();

  @override
  State<_DancingLiveIcon> createState() => _DancingLiveIconState();
}

class _DancingLiveIconState extends State<_DancingLiveIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final wiggle = (t - 0.5) * 0.35; // ~±10° back and forth
        final scale = 0.9 + t * 0.25;
        final glow = 2.0 + t * 5.0;
        return Transform.rotate(
          angle: wiggle,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 14,
              height: 14,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE53935).withValues(alpha: 0.85),
                    blurRadius: glow,
                    spreadRadius: glow * 0.2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.live_tv_rounded,
                size: 9,
                color: Color(0xFFE53935),
              ),
            ),
          ),
        );
      },
    );
  }
}
