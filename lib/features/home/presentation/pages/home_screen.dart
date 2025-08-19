// lib/features/home/presentation/pages/home_screen.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import '../widgets/home_app_bar.dart';
import '../widgets/section_header.dart';
import '../widgets/live_now_section.dart';
import '../widgets/post_list.dart';
import '../widgets/bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Handle tab navigation logic here
    switch (index) {
      case 0:
        // Navigate to Home tab content (already here)
        break;
      case 1:
        // Navigate to Go Live page
        break;
      case 2:
        // Navigate to Post creation page
        break;
      case 3:
        // Navigate to Clubs page
        break;
      case 4:
        // Navigate to Profile page
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              const SectionHeader(title: 'Live Now', trailingFilter: true),
              const SizedBox(height: 8),
              const LiveNowSection(),
              const SizedBox(height: 12),
              const SectionHeader(title: 'Recent Posts', trailingFilter: false),
              const SizedBox(height: 8),
              Expanded(child: PostList()),
              const SizedBox(height: 4),
              HomeBottomNav(currentIndex: _currentIndex, onTap: _onTabSelected),
            ],
          ),
        ),
      ),
    );
  }
}
