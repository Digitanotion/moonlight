import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/notifications/data/models/notification_model.dart';

import '../bloc/notifications_bloc.dart';

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  const NotificationTile({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return GestureDetector(
      onTap: () => context.read<NotificationsBloc>().add(
        MarkNotificationRead(notification.id),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isUnread
                ? [
                    AppColors.primary_.withOpacity(0.18),
                    Colors.black.withOpacity(0.35),
                  ]
                : [
                    Colors.black.withOpacity(0.35),
                    Colors.black.withOpacity(0.25),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isUnread
                ? AppColors.primary_.withOpacity(0.35)
                : Colors.white10,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LeadingIndicator(isUnread: isUnread),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadingIndicator extends StatelessWidget {
  final bool isUnread;
  const _LeadingIndicator({required this.isUnread});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUnread ? AppColors.primary_ : Colors.transparent,
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: AppColors.primary_.withOpacity(0.6),
                  blurRadius: 8,
                ),
              ]
            : [],
      ),
    );
  }
}
