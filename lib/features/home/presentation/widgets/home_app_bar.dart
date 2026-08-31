import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/services/unread_badge_service.dart';
import 'package:moonlight/core/widgets/about_moonlight_sheet.dart';

class HomeAppBar extends StatefulWidget {
  const HomeAppBar({super.key});

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> {
  late final UnreadBadgeService _unreadService;
  Timer? _pollTimer;

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

      // Safety-net poll only — realtime `chat.unread.updated` /
      // `notifications.unread.updated` are the primary path. Kept long (2min)
      // and server-cached so it's negligible even at very high user counts;
      // resume + returning from the chat/notification screens also refresh.
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(minutes: 2), (_) {
        _unreadService.refresh();
      });
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
    _pollTimer?.cancel();
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
          // Tap the logo → "About Moonlight" (legal / company links).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showAboutMoonlightSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Image.asset(
                'assets/images/logo.png',
                width: 36,
                height: 36,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TopIcon(
                icon: Icons.search,
                onTap: () => _navigateToSearch(context),
              ),
              const SizedBox(width: 10),
              // Textual entry point — replaces the bare camera icon, which
              // users did not recognise as "start a private video chat".
              _TopPill(
                icon: Icons.videocam_rounded,
                label: 'Video chat',
                onTap: () => _navigateToVideoCall(context),
              ),
              const SizedBox(width: 10),
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
              const SizedBox(width: 10),
              // Message icon with badge
                           ValueListenableBuilder<int>(
                valueListenable: _unreadService.messageUnreadCount,
                builder: (context, count, child) {
                  return _TopIconWithBadge(
                    icon: Icons.chat_bubble_outline,
                    badgeCount: count,
                    // Was true — meant the actual count silently became
                    // a plain dot once it exceeded 9, even though
                    // _ModernBadge already renders real numbers fine
                    // (up to "99+"). Always show the number.
                    showSmallDot: false,
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

  void _navigateToVideoCall(BuildContext context) {
    Navigator.pushNamed(context, RouteNames.videoCallDirectory);
  }

  Future<void> _navigateToNotification(BuildContext context) async {
    await Navigator.pushNamed(context, RouteNames.notifications);
    // Whatever the notifications screen did (read one / read all), pull the
    // authoritative counts back so the badge is correct on return.
    _unreadService.refresh();
  }

  Future<void> _navigateToConversations(BuildContext context) async {
    await Navigator.pushNamed(context, RouteNames.conversations);
    _unreadService.refresh();
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

/// Compact labelled entry point used in the home app bar. Reads as an
/// action ("Video chat") rather than a bare glyph the user has to guess at.
class _TopPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _TopPill({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textWhite, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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