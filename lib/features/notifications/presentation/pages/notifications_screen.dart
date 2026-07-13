// lib/features/notifications/presentation/screens/notifications_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/utils/time_ago.dart';
import 'package:moonlight/features/notifications/data/models/notification_model.dart';
import 'package:moonlight/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:moonlight/features/notifications/presentation/pages/notification_navigator.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<NotificationsBloc>().add(FetchNotifications());
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      context.read<NotificationsBloc>().add(LoadMoreNotifications());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060F),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: const Color(0xFF05060F),
            surfaceTintColor: Colors.transparent,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 20, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Notifications',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            actions: [
              BlocBuilder<NotificationsBloc, NotificationsState>(
                buildWhen: (p, n) => n is NotificationsLoaded,
                builder: (context, state) {
                  if (state is! NotificationsLoaded) {
                    return const SizedBox.shrink();
                  }
                  final hasUnread = state.items.any((n) => !n.isRead);
                  if (!hasUnread) return const SizedBox.shrink();
                  return TextButton(
                    onPressed: () => context
                        .read<NotificationsBloc>()
                        .add(MarkAllNotificationsRead()),
                    child: const Text('Mark all read',
                        style: TextStyle(
                            color: Color(0xFFFF6A00),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  );
                },
              ),
            ],
          ),
        ],
        body: BlocBuilder<NotificationsBloc, NotificationsState>(
          builder: (context, state) {
            if (state is NotificationsLoading) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFFF6A00), strokeWidth: 2));
            }
            if (state is NotificationsError) {
              return _buildError(context);
            }
            if (state is NotificationsEmpty) {
              return _buildEmpty();
            }
            if (state is NotificationsLoaded) {
              return _buildList(context, state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, NotificationsLoaded state) {
    return RefreshIndicator(
      color: const Color(0xFFFF6A00),
      backgroundColor: const Color(0xFF0E1024),
      onRefresh: () async =>
          context.read<NotificationsBloc>().add(FetchNotifications(refresh: true)),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.items.length + (state.isPaginating ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFFF6A00), strokeWidth: 2)),
            );
          }
          return _NotificationTile(notification: state.items[i]);
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0E1024),
            border: Border.all(color: const Color(0xFF1A1D3D)),
          ),
          child: const Icon(Icons.notifications_none_rounded,
              size: 32, color: Colors.white38),
        ),
        const SizedBox(height: 16),
        const Text('No notifications yet',
            style: TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Activity will appear here',
            style: TextStyle(color: Color(0xFF8B8FB8), fontSize: 13.5)),
      ]),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white38, size: 40),
        const SizedBox(height: 12),
        const Text('Failed to load notifications',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6A00)),
          onPressed: () =>
              context.read<NotificationsBloc>().add(FetchNotifications()),
          child: const Text('Retry'),
        ),
      ]),
    );
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  const _NotificationTile({required this.notification});

  bool get _isNavigable {
    // Types that have a meaningful destination
    const navigable = {
      'post.liked', 'post.comment', 'post.comment_liked',
      'post.comment_replied', 'post.tagged',
      'user.followed', 'user.follow_request',
      'live.started', 'live.guest_invited',
      'wallet.coins_received', 'wallet.gift_received',
      'auth.login', 'auth.password_changed',
    };
    return navigable.contains(notification.type);
  }

  IconData _iconFor(String type) {
    if (type.startsWith('post.')) return Icons.article_rounded;
    if (type.startsWith('user.')) return Icons.person_rounded;
    if (type.startsWith('live.')) return Icons.live_tv_rounded;
    if (type.startsWith('wallet.')) return Icons.toll_rounded;
    if (type.startsWith('auth.')) return Icons.security_rounded;
    return Icons.notifications_rounded;
  }

  Color _colorFor(String type) {
    if (type.startsWith('post.')) return const Color(0xFFFF6A00);
    if (type.startsWith('user.')) return const Color(0xFF3B82F6);
    if (type.startsWith('live.')) return const Color(0xFFEF4444);
    if (type.startsWith('wallet.')) return const Color(0xFF10B981);
    if (type.startsWith('auth.')) return const Color(0xFF8B5CF6);
    return const Color(0xFF8B8FB8);
  }

  /// Every tap opens the detail sheet — a single, predictable entry
  /// point for reading the full message, whether or not the notification
  /// has a destination screen.
  void _handleTap(BuildContext context) {
    if (!notification.isRead) {
      context.read<NotificationsBloc>().add(MarkNotificationRead(notification.id));
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _NotificationDetailSheet(
        notification: notification,
        isNavigable: _isNavigable,
        accentColor: _colorFor(notification.type),
        icon: _iconFor(notification.type),
        ctaLabel: _ctaLabel(notification.type),
        onCta: () {
          Navigator.pop(sheetContext); // close sheet first
          final handled = NotificationNavigator.navigate(context, notification);
          if (!handled) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(notification.title),
              backgroundColor: const Color(0xFF0E1024),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = !n.isRead;
    final accentColor = _colorFor(n.type);

    return InkWell(
      onTap: () => _handleTap(context),
      splashColor: accentColor.withOpacity(0.08),
      highlightColor: accentColor.withOpacity(0.04),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: unread
              ? accentColor.withOpacity(0.06)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: unread ? accentColor : Colors.transparent,
              width: 3,
            ),
            bottom: const BorderSide(color: Color(0xFF1A1D3D), width: 0.5),
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar or icon
          _buildAvatar(n, accentColor),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(n.title,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                          height: 1.3)),
                ),
                const SizedBox(width: 8),
                Text(timeAgoFrom(n.createdAt),
                    style: TextStyle(
                        color: const Color(0xFF8B8FB8),
                        fontSize: 11,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.normal)),
              ]),
              if (n.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF8B8FB8),
                        fontSize: 13,
                        height: 1.4)),
              ],
              // "Read more" affordance appears whenever the body is long
              // enough that it's likely truncated at 2 lines above — a
              // cheap length check rather than measuring text layout.
              if (n.body.length > 80) ...[
                const SizedBox(height: 4),
                Text('Read more',
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
              ],
              if (_isNavigable) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(_iconFor(n.type), size: 12, color: accentColor),
                  const SizedBox(width: 4),
                  Text(_ctaLabel(n.type),
                      style: TextStyle(
                          color: accentColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 9, color: accentColor.withOpacity(0.7)),
                ]),
              ],
            ]),
          ),
          // Unread dot
          if (unread) ...[
            const SizedBox(width: 8),
            Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: accentColor),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildAvatar(NotificationModel n, Color accentColor) {
    final avatarUrl = n.actor?.avatarUrl ?? '';
    final hasAvatar = avatarUrl.isNotEmpty &&
        Uri.tryParse(avatarUrl)?.hasScheme == true;

    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1A1D3D), width: 1.5),
        ),
        child: ClipOval(
          child: hasAvatar
              ? CachedNetworkImage(
                  imageUrl: avatarUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                      color: accentColor.withOpacity(0.15),
                      child: Icon(Icons.person_rounded,
                          size: 22, color: Colors.white54)),
                  errorWidget: (_, __, ___) => Container(
                      color: accentColor.withOpacity(0.15),
                      child: Icon(Icons.person_rounded,
                          size: 22, color: Colors.white54)),
                )
              : Container(
                  color: accentColor.withOpacity(0.15),
                  child: Icon(_iconFor(n.type), size: 22, color: accentColor)),
        ),
      ),
      // Small type icon badge on avatar
      Positioned(
        bottom: -2, right: -2,
        child: Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor,
            border: Border.all(color: const Color(0xFF05060F), width: 1.5),
          ),
          child: Icon(_iconFor(n.type), size: 10, color: Colors.white),
        ),
      ),
    ]);
  }

  String _ctaLabel(String type) => switch (type) {
    'post.liked'           => 'View post',
    'post.comment'         => 'View comment',
    'post.comment_liked'   => 'View comment',
    'post.comment_replied' => 'View reply',
    'post.tagged'          => 'View post',
    'user.followed'        => 'View profile',
    'user.follow_request'  => 'View profile',
    'live.started'         => 'Join stream',
    'live.guest_invited'   => 'Join as guest',
    'wallet.coins_received'=> 'View wallet',
    'wallet.gift_received' => 'View wallet',
    'auth.login'           => 'Review security',
    'auth.password_changed'=> 'Review security',
    _                      => 'View',
  };
}

// ── Notification detail sheet ─────────────────────────────────────────────────

/// Bottom sheet shown on tap, before any navigation happens. Gives the
/// person the full title + body (never truncated), who it's from, and
/// when — then a single clear CTA if there's somewhere to go. This
/// replaces the old behavior of either silently marking read or jumping
/// straight to another screen with no context.
class _NotificationDetailSheet extends StatelessWidget {
  final NotificationModel notification;
  final bool isNavigable;
  final Color accentColor;
  final IconData icon;
  final String ctaLabel;
  final VoidCallback onCta;

  const _NotificationDetailSheet({
    required this.notification,
    required this.isNavigable,
    required this.accentColor,
    required this.icon,
    required this.ctaLabel,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final avatarUrl = n.actor?.avatarUrl ?? '';
    final hasAvatar = avatarUrl.isNotEmpty &&
        Uri.tryParse(avatarUrl)?.hasScheme == true;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1024),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1A1D3D)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Stack(clipBehavior: Clip.none, children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF1A1D3D), width: 1.5),
                            ),
                            child: ClipOval(
                              child: hasAvatar
                                  ? CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                          color: accentColor.withOpacity(0.15),
                                          child: Icon(Icons.person_rounded,
                                              size: 24, color: Colors.white54)),
                                      errorWidget: (_, __, ___) => Container(
                                          color: accentColor.withOpacity(0.15),
                                          child: Icon(Icons.person_rounded,
                                              size: 24, color: Colors.white54)),
                                    )
                                  : Container(
                                      color: accentColor.withOpacity(0.15),
                                      child: Icon(icon,
                                          size: 24, color: accentColor)),
                            ),
                          ),
                          Positioned(
                            bottom: -2, right: -2,
                            child: Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor,
                                border: Border.all(
                                    color: const Color(0xFF0E1024), width: 1.5),
                              ),
                              child: Icon(icon, size: 11, color: Colors.white),
                            ),
                          ),
                        ]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((n.actor?.fullname ?? '').isNotEmpty)
                                Text(n.actor!.fullname,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700)),
                              Text(timeAgoFrom(n.createdAt),
                                  style: const TextStyle(
                                      color: Color(0xFF8B8FB8), fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(n.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.35)),
                    if (n.body.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(n.body,
                          style: const TextStyle(
                              color: Color(0xFFC5C8D6),
                              fontSize: 14.5,
                              height: 1.55)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (isNavigable) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: onCta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(ctaLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}