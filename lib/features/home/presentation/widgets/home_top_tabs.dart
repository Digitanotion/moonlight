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
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/feed/presentation/pages/feed_screen.dart';
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
  late final UnreadBadgeService _unreadService;
  Timer? _pollTimer;

  int _lastRealIndex = 0; // Watch or Discover — never Video Chat
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChange);

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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showAboutMoonlightSheet(context),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 32,
                    height: 32,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TabBar(
                    controller: _tabs,
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
                    tabs: const [
                      Tab(text: 'Watch'),
                      Tab(text: 'Discover'),
                      Tab(text: 'Video Chat'),
                    ],
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
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                const HomeDiscoverGrid(),
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
