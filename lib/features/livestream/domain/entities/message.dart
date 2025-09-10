// lib/features/livestream/domain/entities/message.dart
class Message {
  final String uuid;
  final String text;
  final String userUuid;
  final String userDisplay;
  final String? userAvatarUrl;
  final DateTime createdAt;
  final Map<String, dynamic>? gift;

  const Message({
    required this.uuid,
    required this.text,
    required this.userUuid,
    required this.userDisplay,
    required this.createdAt,
    this.userAvatarUrl,
    this.gift,
  });
}
