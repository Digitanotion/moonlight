import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_bloc.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/section_header.dart';
import '../widgets/live_now_section.dart';
import '../widgets/bottom_nav.dart';
import '../../../../core/injection_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushNamed(context, '/go-live');
        break;
      case 2:
        Navigator.pushNamed(context, '/posts');
        break;
      case 3:
        Navigator.pushNamed(context, '/clubs');
        break;
      case 4:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LiveFeedBloc>(), // DO NOT trigger load here
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.dark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HomeAppBar(),
                const SizedBox(height: 8),

                // Header row: SectionHeader + See Posts
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: SectionHeader(
                          title: 'Live Now',
                          trailingFilter: true,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, RouteNames.postsPage),
                        child: const Text(
                          'See Posts',
                          style: TextStyle(
                            color: AppColors.primary_,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Vertical grid feed (pull-to-refresh inside)
                const LiveNowSection(),

                // Bottom nav
                HomeBottomNav(
                  currentIndex: _currentIndex,
                  onTap: _onTabSelected,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
