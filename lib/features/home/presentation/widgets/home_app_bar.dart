// lib/features/home/presentation/widgets/home_app_bar.dart
import 'package:flutter/material.dart';
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
            children: const [
              _TopIcon(icon: Icons.search),
              SizedBox(width: 14),
              _TopIcon(icon: Icons.notifications_none),
              SizedBox(width: 14),
              _TopIcon(icon: Icons.chat_bubble_outline),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  const _TopIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.textWhite, size: 20),
    );
  }
}
