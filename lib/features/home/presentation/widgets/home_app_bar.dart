import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Moonlight',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textWhite,
              fontWeight: FontWeight.w800,
            ),
          ),
          Row(
            children: [
              _TopIcon(
                icon: Icons.search,
                onTap: () => _navigateToSearch(context),
              ),
              const SizedBox(width: 14),
              _TopIcon(
                icon: Icons.notifications_none,
                onTap: () => _navigateToNotification(context),
              ),
              const SizedBox(width: 14),
              _TopIcon(
                icon: Icons.chat_bubble_outline,
                onTap: () => _navigateToConversations(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToSearch(BuildContext context) {
    Navigator.pushNamed(context, RouteNames.search);
  }

  void _navigateToNotification(BuildContext context) {
    Navigator.pushNamed(context, RouteNames.notifications);
  }

  void _navigateToConversations(BuildContext context) {
    Navigator.pushNamed(context, RouteNames.conversations);
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _TopIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.textWhite, size: 20),
      ),
    );
  }
}
