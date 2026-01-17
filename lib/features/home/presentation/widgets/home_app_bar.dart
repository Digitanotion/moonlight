import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/services/unread_badge_service.dart';

class HomeAppBar extends StatefulWidget {
  const HomeAppBar({super.key});

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> {
  late final UnreadBadgeService _unreadService;

  @override
  void initState() {
    super.initState();
    _unreadService = GetIt.instance<UnreadBadgeService>();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      // Initialize the unread service
      await _unreadService.initialize();

      // Listen for count changes
      _unreadService.messageUnreadCount.addListener(_updateUI);
      _unreadService.notificationUnreadCount.addListener(_updateUI);

      // Trigger initial update
      _updateUI();
    } catch (e) {
      debugPrint('HomeAppBar: Error initializing unread service: $e');
    }
  }

  void _updateUI() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _unreadService.messageUnreadCount.removeListener(_updateUI);
    _unreadService.notificationUnreadCount.removeListener(_updateUI);
    super.dispose();
  }

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
              // Notification icon with badge
              ValueListenableBuilder<int>(
                valueListenable: _unreadService.notificationUnreadCount,
                builder: (context, count, child) {
                  return _TopIconWithBadge(
                    icon: Icons.notifications_none,
                    badgeCount: count,
                    onTap: () async {
                      // Mark notifications as read when tapped
                      try {
                        // await _unreadService.markNotificationsAsRead();
                        _navigateToNotification(context);
                      } catch (e) {
                        debugPrint('Error marking notifications as read: $e');
                        _navigateToNotification(context);
                      }
                    },
                  );
                },
              ),
              const SizedBox(width: 14),
              // Message icon with badge
              ValueListenableBuilder<int>(
                valueListenable: _unreadService.messageUnreadCount,
                builder: (context, count, child) {
                  return _TopIconWithBadge(
                    icon: Icons.chat_bubble_outline,
                    badgeCount: count,
                    showSmallDot: true,
                    onTap: () => _navigateToConversations(context),
                  );
                },
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

class _TopIconWithBadge extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback? onTap;
  final bool showSmallDot;
  final double iconSize;
  final double badgeMinSize;

  const _TopIconWithBadge({
    required this.icon,
    this.badgeCount = 0,
    this.onTap,
    this.showSmallDot = false,
    this.iconSize = 20,
    this.badgeMinSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final bool showBadge = badgeCount > 0;
    print(
      '_TopIconWithBadge: count=$badgeCount, showBadge=$showBadge',
    ); // Debug

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.textWhite, size: iconSize),
            ),

            if (showBadge) ...[
              // Show badge position for debugging
              Positioned(
                top: -6, // Increased from -4 to -6
                right: -6, // Increased from -4 to -6
                child: Container(
                  // decoration: BoxDecoration(
                  //   border: Border.all(color: Colors.red, width: 1),
                  // ),
                  child: _ModernBadge(
                    count: badgeCount,
                    showSmallDot: showSmallDot && badgeCount > 9,
                  ),
                ),
              ),
            ] else ...[
              // Show position indicator when no badge (for debugging)
              // Positioned(
              //   top: -6,
              //   right: -6,
              //   child: Container(
              //     width: 4,
              //     height: 4,
              //     color: Colors.green,
              //   ),
              // ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModernBadge extends StatelessWidget {
  final int count;
  final bool showSmallDot;

  const _ModernBadge({required this.count, this.showSmallDot = false});

  @override
  Widget build(BuildContext context) {
    print('_ModernBadge: count=$count, showSmallDot=$showSmallDot'); // Debug

    if (showSmallDot) {
      // Twitter-style small dot for high numbers
      return Container(
        width: 12, // Increased from 10
        height: 12, // Increased from 10
        decoration: BoxDecoration(
          color:
              AppColors.textRed, // Changed to use textRed for better visibility
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white,
            width: 1,
          ), // Increased from 1.5
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3), // Increased opacity
              blurRadius: 3, // Increased from 2
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );
    }

    // TikTok/Facebook style badge with count
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 4,
      ), // Increased padding
      constraints: const BoxConstraints(
        minWidth: 20,
        minHeight: 20,
      ), // Increased min size
      decoration: BoxDecoration(
        color: AppColors.textRed,
        borderRadius: BorderRadius.circular(12), // Slightly larger
        border: Border.all(color: Colors.white, width: 1), // Increased from 1.5
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4, // Increased from 3
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11, // Slightly larger
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -0.5, // Better spacing for small text
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class NotificationManager {
  static final ValueNotifier<int> notificationCount = ValueNotifier<int>(0);
  static final ValueNotifier<int> messageCount = ValueNotifier<int>(0);

  static void incrementNotification() {
    notificationCount.value++;
    print('Notification incremented to: ${notificationCount.value}');
  }

  static void decrementNotification() {
    notificationCount.value = (notificationCount.value - 1).clamp(0, 99);
    print('Notification decremented to: ${notificationCount.value}');
  }

  static void incrementMessage() {
    messageCount.value++;
    print('Message incremented to: ${messageCount.value}');
  }

  static void decrementMessage() {
    messageCount.value = (messageCount.value - 1).clamp(0, 99);
    print('Message decremented to: ${messageCount.value}');
  }

  static void resetNotification() {
    notificationCount.value = 0;
    print('Notifications reset to 0');
  }

  static void resetMessage() {
    messageCount.value = 0;
    print('Messages reset to 0');
  }

  // Test function to add sample data
  static void addTestData() {
    notificationCount.value = 6;
    messageCount.value = 12;
    print('Test data added: notifications=6, messages=12');
  }
}
