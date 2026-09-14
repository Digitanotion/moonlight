// lib/features/home/presentation/widgets/home_top_tabs.dart
//
// TikTok-style swipeable strip under the home header: "Watch" (merged
// live+video discover grid), "Discover" (the Posts feed, truly embedded —
// not a disguised navigation), and "Video Chat" (today's directory
// screen).
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/feed/presentation/pages/feed_screen.dart';
import 'package:moonlight/features/home/presentation/widgets/home_discover_grid.dart';

class HomeTopTabs extends StatefulWidget {
  const HomeTopTabs({super.key});

  @override
  State<HomeTopTabs> createState() => _HomeTopTabsState();
}

class _HomeTopTabsState extends State<HomeTopTabs>
    with SingleTickerProviderStateMixin {
  static const _videoChatTabIndex = 2;

  late final TabController _tabs = TabController(length: 3, vsync: this);
  late final FeedCubit _discoverCubit = sl<FeedCubit>()..loadFirstPage();

  int _lastRealIndex = 0; // Watch or Discover — never Video Chat
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (!_tabs.indexIsChanging) return;
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

  @override
  void dispose() {
    _tabs.removeListener(_onTabChange);
    _tabs.dispose();
    _discoverCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                const HomeDiscoverGrid(),
                BlocProvider.value(
                  value: _discoverCubit,
                  child: const FeedBody(),
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
