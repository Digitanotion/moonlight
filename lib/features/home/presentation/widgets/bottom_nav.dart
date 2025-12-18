// lib/features/home/presentation/widgets/bottom_nav.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/livestream/presentation/pages/livestream_ended.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_page_cubit.dart';

class HomeBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const HomeBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<HomeBottomNav> createState() => _HomeBottomNavState();
}

class _HomeBottomNavState extends State<HomeBottomNav> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: widget.currentIndex == 0,
                onTap: () => widget.onTap(0),
              ),
              _NavItem(
                icon: Icons.videocam_outlined,
                label: 'Go Live',
                active: widget.currentIndex == 1,
                onTap: () => Navigator.of(context).pushNamed(RouteNames.goLive),
              ),

              /// Emphasized Post Button (Floating style)
              GestureDetector(
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.createPost),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.6),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, size: 30, color: Colors.white),
                ),
              ),

              _NavItem(
                icon: Icons.groups_2_outlined,
                label: 'Clubs',
                active: widget.currentIndex == 3,
                onTap: () {
                  widget.onTap(3);
                  Navigator.pushNamed(context, RouteNames.clubs);
                },
              ),

              _NavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                active: widget.currentIndex == 4,
                onTap: () {
                  // widget.onTap(4);
                  Navigator.pushNamed(context, RouteNames.myProfile);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: active ? 24 : 22,
                color: active ? AppColors.secondary : Colors.white70,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: active ? AppColors.secondary : Colors.white70,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
