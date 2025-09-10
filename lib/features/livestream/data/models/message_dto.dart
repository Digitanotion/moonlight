// lib/features/livestream/data/models/message_dto.dart
import '../../domain/entities/message.dart';

class MessageDto {
  final String uuid;
  final String text;
  final AuthorMini user;
  final DateTime createdAt;
  final Map<String, dynamic>? gift;

  MessageDto({
    required this.uuid,
    required this.text,
    required this.user,
    required this.createdAt,
    this.gift,
  });

  factory MessageDto.fromJson(Map<String, dynamic> j) => MessageDto(
    uuid: (j['uuid'] ?? j['id']).toString(),
    text: j['text'] ?? '',
    user: AuthorMini.fromJson(j['user'] ?? const {}),
    createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
    gift: j['gift'],
  );

  Message toEntity() => Message(
    uuid: uuid,
    text: text,
    userUuid: user.uuid,
    userDisplay: user.display,
    userAvatarUrl: user.avatarUrl,
    createdAt: createdAt,
    gift: gift,
  );
}

class AuthorMini {
  final String uuid;
  final String display;
  final String? avatarUrl;
  AuthorMini({required this.uuid, required this.display, this.avatarUrl});
  factory AuthorMini.fromJson(Map<String, dynamic> j) => AuthorMini(
    uuid: j['uuid'] ?? '',
    display: j['display'] ?? '',
    avatarUrl: j['avatar_url'],
  );
}
