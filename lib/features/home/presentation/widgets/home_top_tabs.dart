// lib/features/home/presentation/widgets/home_top_tabs.dart
//
// TikTok-style swipeable strip under the home header: "Live" (the merged
// live+video discover grid) and "Video Chat" (today's directory screen).
//
// Video Chat isn't embedded inline — that screen owns a full Scaffold/AppBar
// of its own, and duplicating that under this header would look wrong and
// risks touching a screen that already works. Instead, swiping/tapping to
// that tab pushes the exact same unmodified route it always used to reach
// from the header pill, then the tab springs back to "Live" once you
// return — same destination, same behavior, just reached by swipe now
// instead of a header button.

import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/home/presentation/widgets/home_discover_grid.dart';

class HomeTopTabs extends StatefulWidget {
  const HomeTopTabs({super.key});

  @override
  State<HomeTopTabs> createState() => _HomeTopTabsState();
}

class _HomeTopTabsState extends State<HomeTopTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (_navigating) return;
    if (_tabs.indexIsChanging && _tabs.index == 1) {
      _navigating = true;
      Navigator.of(context).pushNamed(RouteNames.videoCallDirectory).then((_) {
        _navigating = false;
        if (mounted) _tabs.animateTo(0);
      });
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChange);
    _tabs.dispose();
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
                Tab(text: 'Live'),
                Tab(text: 'Video Chat'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Always the discover grid — "Video Chat" never actually renders
          // as tab content, it's a navigation trigger (see _onTabChange).
          const HomeDiscoverGrid(),
        ],
      ),
    );
  }
}
