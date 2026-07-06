// lib/features/notifications/presentation/notification_navigator.dart
//
// Central place that maps notification type → navigation action.
// Called from both the NotificationsScreen tile tap AND from FCM
// push notification tap (so routing logic lives in one place).

import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/notifications/data/models/notification_model.dart';

class NotificationNavigator {
  NotificationNavigator._();

  /// Navigate to the correct screen for a given notification.
  /// Returns true if navigation was handled, false if unhandled.
  static bool navigate(BuildContext context, NotificationModel n) {
    switch (n.type) {
      // ── Post interactions ─────────────────────────────────────────
      case 'post.liked':
      case 'post.comment':
      case 'post.comment_liked':
      case 'post.comment_replied':
      case 'post.tagged':
        final postId = _resolvePostId(n);
        if (postId == null) return false;
        Navigator.pushNamed(
          context,
          RouteNames.postView,
          arguments: {'postId': postId},
        );
        return true;

      // ── Profile / social ─────────────────────────────────────────
      case 'user.followed':
      case 'user.follow_request':
        final actorUuid = n.actor?.uuid ?? n.meta.userUuid;
        if (actorUuid == null || actorUuid.isEmpty) return false;
        Navigator.pushNamed(
          context,
          RouteNames.profileView,
          arguments: {
            'userUuid': actorUuid,
            'user_slug': n.actor?.slug ?? '',
          },
        );
        return true;

      // ── Live stream ───────────────────────────────────────────────
      case 'live.started':
      case 'live.guest_invited':
        final liveUuid = n.meta.liveUuid;
        if (liveUuid == null || liveUuid.isEmpty) return false;
        Navigator.pushNamed(
          context,
          RouteNames.liveViewer,
          arguments: {'uuid': liveUuid},
        );
        return true;

      // ── Wallet / coins ────────────────────────────────────────────
      case 'wallet.coins_received':
      case 'wallet.gift_received':
        Navigator.pushNamed(context, RouteNames.wallet);
        return true;

      // ── Auth / security ───────────────────────────────────────────
      case 'auth.login':
      case 'auth.password_changed':
        Navigator.pushNamed(context, RouteNames.accountSettings);
        return true;

      // ── Unhandled — don't navigate ─────────────────────────────
      default:
        return false;
    }
  }

  /// Extract the post UUID from meta or action_url.
  static String? _resolvePostId(NotificationModel n) {
    // Prefer explicit uuid in meta
    if (n.meta.postUuid != null && n.meta.postUuid!.isNotEmpty) {
      return n.meta.postUuid;
    }
    // Fall back to action_url: extract UUID from URL path
    // e.g. https://svc.moonlightstream.app/posts/c69557ba-2180-4dbe-...
    final url = n.actionUrl;
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final segments = uri.pathSegments;
        // Find the segment after "posts"
        final postsIdx = segments.indexOf('posts');
        if (postsIdx != -1 && postsIdx + 1 < segments.length) {
          return segments[postsIdx + 1];
        }
        // Last segment is often the UUID
        if (segments.isNotEmpty) return segments.last;
      }
    }
    return null;
  }
}