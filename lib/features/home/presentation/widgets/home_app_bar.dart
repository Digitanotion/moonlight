// lib/features/home/presentation/widgets/home_app_bar.dart
//
// The standalone header row (logo/search/notifications/messages/profile)
// was merged into HomeTopTabs so the logo, tabs, and account button all sit
// on one line — see home_top_tabs.dart for where these are actually used
// now. What's left here are the reusable pieces that moved with it.

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';

/// Single entry point for Notifications/Messages/Profile — avatar with a
/// combined unread dot, opens a compact sheet with all three. Reduces the
/// header's tappable element count without hiding anything — each
/// destination is still one tap away, just behind one button instead of
/// three.
class AccountButton extends StatelessWidget {
  final int notificationCount;
  final int messageCount;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenMessages;

  const AccountButton({
    super.key,
    required this.notificationCount,
    required this.messageCount,
    required this.onOpenNotifications,
    required this.onOpenMessages,
  });

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.dark.withValues(alpha: 0.72),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    _MenuRow(
                      icon: Icons.notifications_none,
                      label: 'Notifications',
                      count: notificationCount,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onOpenNotifications();
                      },
                    ),
                    _MenuRow(
                      icon: Icons.chat_bubble_outline,
                      label: 'Messages',
                      count: messageCount,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onOpenMessages();
                      },
                    ),
                    _MenuRow(
                      icon: Icons.person_outline,
                      label: 'My Profile',
                      isLast: true,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.pushNamed(context, RouteNames.myProfile);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = GetIt.instance<CurrentUserService>().getCurrentAvatar();
    final hasUnread = notificationCount > 0 || messageCount > 0;

    return GestureDetector(
      onTap: () => _openMenu(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    Container(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
          if (hasUnread)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF3B5C),
                  border: Border.all(color: AppColors.dark, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tango-style: a plain row, no boxed border/card — icon, label, and a
/// hairline divider between rows instead of a bordered container each.
/// Simple, not busy.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;
  final bool isLast;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.count,
    this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: Colors.white70, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (count != null && count! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B5C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      count! > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
      ],
    );
  }
}
