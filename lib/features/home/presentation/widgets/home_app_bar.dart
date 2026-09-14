import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/services/unread_badge_service.dart';
import 'package:moonlight/core/widgets/about_moonlight_sheet.dart';

class HomeAppBar extends StatefulWidget {
  const HomeAppBar({super.key});

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> with WidgetsBindingObserver {
  late final UnreadBadgeService _unreadService;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unreadService = GetIt.instance<UnreadBadgeService>();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _unreadService.initialize();

      _unreadService.messageUnreadCount.addListener(_updateUI);
      _unreadService.notificationUnreadCount.addListener(_updateUI);
      _updateUI();

      _startPoll();
    } catch (e) {
      debugPrint('HomeAppBar: Error initializing unread service: $e');
    }
  }

  // Realtime (`chat.unread.updated` / `notifications.unread.updated`) is the
  // primary path; this is only a safety net for a dropped socket. 5 min,
  // foreground-only — nothing fires while the app is backgrounded.
  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _unreadService.refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pollTimer == null) _startPoll();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _updateUI() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
              // Video chat moved out of the header — it's now the "Video
              // Chat" tab in the swipeable strip below (HomeTopTabs), which
              // gives it a roomier, self-explanatory home instead of
              // competing for width here.
              //
              // Notifications + Messages + Profile consolidated into one
              // account button — opens a compact popover instead of 3
              // separate icons competing for header width.
              ListenableBuilder(
                listenable: Listenable.merge([
                  _unreadService.notificationUnreadCount,
                  _unreadService.messageUnreadCount,
                ]),
                builder: (context, _) {
                  return _AccountButton(
                    notificationCount:
                        _unreadService.notificationUnreadCount.value,
                    messageCount: _unreadService.messageUnreadCount.value,
                    onOpenNotifications: () => _navigateToNotification(context),
                    onOpenMessages: () => _navigateToConversations(context),
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

/// Single entry point replacing the old separate Notifications/Messages
/// icons — avatar with a combined unread dot, opens a compact sheet with
/// Notifications, Messages, and My Profile. Reduces the header's tappable
/// element count without hiding anything — each destination is still one
/// tap away, just behind one button instead of three.
class _AccountButton extends StatelessWidget {
  final int notificationCount;
  final int messageCount;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenMessages;

  const _AccountButton({
    required this.notificationCount,
    required this.messageCount,
    required this.onOpenNotifications,
    required this.onOpenMessages,
  });

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1024),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white12,
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
              const SizedBox(height: 10),
              _MenuRow(
                icon: Icons.chat_bubble_outline,
                label: 'Messages',
                count: messageCount,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onOpenMessages();
                },
              ),
              const SizedBox(height: 10),
              _MenuRow(
                icon: Icons.person_outline,
                label: 'My Profile',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, RouteNames.myProfile);
                },
              ),
            ],
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
              border: Border.all(color: Colors.white.withOpacity(0.16)),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    Container(color: Colors.white.withOpacity(0.08)),
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

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(icon, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (count != null && count! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(right: 8),
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
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
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
