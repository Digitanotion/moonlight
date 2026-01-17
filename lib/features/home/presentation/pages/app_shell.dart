import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/ui/empty_tab.dart';
import 'package:moonlight/features/home/presentation/pages/animated_tab_stack.dart';
import 'package:moonlight/features/home/presentation/pages/home_screen.dart';
import 'package:moonlight/features/clubs/presentation/pages/discover_clubs_tab.dart';
import 'package:moonlight/features/profile_setup/presentation/pages/my_profile_tab.dart';
import 'package:moonlight/widgets/top_snack.dart';
import '../widgets/bottom_nav.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  DateTime? _lastBackPress;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = const [
      HomeScreen(), // 0
      EmptyTab(), // 1 (Go Live modal)
      EmptyTab(), // 2 (Create Post modal)
      DiscoverClubsTab(), // 3
      MyProfileTab(), // 4
    ];
  }

  void _onTabSelected(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  Future<bool> _handleBack() async {
    // 1️⃣ If not on Home → go Home instead of exiting
    if (_index != 0) {
      setState(() => _index = 0);
      HapticFeedback.selectionClick();
      return false;
    }

    // 2️⃣ Double-back to exit
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      TopSnack.info(context, 'Press back again to exit');
      HapticFeedback.selectionClick();
      return false;
    }

    // 3️⃣ Allow system exit
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // ⛔ block default system pop
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldExit = await _handleBack();
        if (shouldExit && mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: AnimatedTabStack(index: _index, children: _tabs),
        bottomNavigationBar: HomeBottomNav(
          currentIndex: _index,
          onTabSelected: _onTabSelected,
          onGoLive: () {
            Navigator.pushNamed(context, RouteNames.goLive);
          },
          onCreatePost: () {
            Navigator.pushNamed(context, RouteNames.createPost);
          },
        ),
      ),
    );
  }
}
