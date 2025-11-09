// lib/features/gift_coins/domain/entities/gift_user.dart
class GiftUser {
  final String username; // with @
  final String fullName;
  final String avatar; // url
  final String uuid;

  GiftUser({
    required this.username,
    required this.fullName,
    required this.avatar,
    required this.uuid,
  });
}
