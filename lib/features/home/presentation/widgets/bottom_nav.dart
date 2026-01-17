import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/theme/app_colors.dart';

/// PROFESSIONAL HOME BOTTOM NAV
/// ------------------------------------------------------------
/// Rules enforced:
/// 1. Tabs NEVER push routes
/// 2. Only change index for persistent pages
/// 3. Modal actions (Go Live, Create Post) push routes
/// 4. Active feedback + haptics for premium UX
/// ------------------------------------------------------------

class HomeBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onGoLive;
  final VoidCallback onCreatePost;

  const HomeBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onGoLive,
    required this.onCreatePost,
  });

  void _handleTabTap(int index) {
    if (currentIndex == index) {
      // Subtle haptic = "you are already here"
      HapticFeedback.selectionClick();
      return;
    }

    HapticFeedback.lightImpact();
    onTabSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                activeIndex: currentIndex,
                onTap: _handleTabTap,
              ),

              _ActionItem(
                icon: Icons.post_add_outlined,
                label: 'New Post',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onCreatePost();
                },
              ),

              _CreatePostButton(
                onTap: () {
                  HapticFeedback.heavyImpact();

                  onGoLive();
                },
              ),

              _NavItem(
                icon: Icons.groups_2_outlined,
                label: 'Clubs',
                index: 3,
                activeIndex: currentIndex,
                onTap: _handleTabTap,
              ),

              _NavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                index: 4,
                activeIndex: currentIndex,
                onTap: _handleTabTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ───────────────── TAB ITEM ─────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int activeIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.activeIndex,
    required this.onTap,
  });

  bool get _isActive => index == activeIndex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _isActive
                ? Colors.white.withOpacity(0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: _isActive ? 1.12 : 1.0,
                child: Icon(
                  icon,
                  size: 24,
                  color: _isActive ? AppColors.secondary : Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isActive ? 1 : 0.65,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _isActive ? AppColors.secondary : Colors.white70,
                    fontWeight: _isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ───────────────── ACTION ITEM (NON-TAB) ─────────────────

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// ───────────────── CENTER CREATE BUTTON ─────────────────

class _CreatePostButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreatePostButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.6),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.videocam_outlined,
              size: 30,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
