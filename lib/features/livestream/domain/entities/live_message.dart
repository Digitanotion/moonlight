// lib/features/livestream/domain/entities/live_message.dart
class LiveMessageUser {
  final String uuid;
  final String display;
  final String? avatarUrl;
  final String? badge; // VIP/Superstar etc.
  const LiveMessageUser({
    required this.uuid,
    required this.display,
    this.avatarUrl,
    this.badge,
  });
}

class LiveMessage {
  final String uuid;
  final LiveMessageUser user;
  final String? text;
  final String? giftNotice; // server gift -> inject as notice
  final DateTime createdAt;

  const LiveMessage({
    required this.uuid,
    required this.user,
    this.text,
    this.giftNotice,
    required this.createdAt,
  });

  String get timeAgo {
    final d = DateTime.now().difference(createdAt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }
}
