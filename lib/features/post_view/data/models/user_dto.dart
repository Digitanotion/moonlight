import '../../domain/entities/user.dart';

class AppUserDto {
  final String uuid;
  final String slug;
  final String name;
  final String avatarUrl;
  final String countryFlagEmoji;
  final String roleLabel;
  final String roleColor;
  final bool isFollowing;

  AppUserDto({
    required this.uuid,
    required this.slug,
    required this.name,
    required this.avatarUrl,
    required this.countryFlagEmoji,
    required this.roleLabel,
    required this.roleColor,
    this.isFollowing = false,
  });

  factory AppUserDto.fromMap(Map<String, dynamic> m) => AppUserDto(
    uuid: '${m['uuid'] ?? m['id'] ?? ''}',
    slug: '${m['user_slug'] ?? m['slug'] ?? ''}',
    name: '${m['name'] ?? ''}',
    avatarUrl: '${m['avatarUrl'] ?? m['avatar'] ?? ''}',
    countryFlagEmoji: '${m['countryFlagEmoji'] ?? m['flag'] ?? ''}',
    roleLabel: '${m['roleLabel'] ?? m['role'] ?? ''}',
    roleColor: '${m['roleColor'] ?? '#ADB5BD'}',
    isFollowing: m['isFollowing'] == true || m['is_following'] == true,
  );

  AppUser toEntity() => AppUser(
    id: uuid, // keep your int id requirement
    name: name,
    avatarUrl: avatarUrl,
    countryFlagEmoji: countryFlagEmoji,
    roleLabel: roleLabel,
    roleColor: roleColor,
    isFollowing: isFollowing,
  );
}
