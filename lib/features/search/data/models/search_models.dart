class UserModel {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final int followersCount;
  final bool isFollowing;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.followersCount = 0,
    this.isFollowing = false,
  });

  /// Works for:
  /// - /search
  /// - /search/suggested-users
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: (map['uuid'] ?? '').toString(),
      name: map['fullname'] ?? map['name'] ?? map['user_slug'] ?? 'Unknown',
      username: map['user_slug'] ?? '',
      avatarUrl: map['avatar_url'],
      followersCount: (map['followers_count'] as num?)?.toInt() ?? 0,
      isFollowing: map['followed_by_me'] == true,
    );
  }
}

class ClubModel {
  final String id;
  final String name;
  final String description;
  final int membersCount;
  final String? coverImageUrl;
  final bool isMember;

  const ClubModel({
    required this.id,
    required this.name,
    required this.description,
    required this.membersCount,
    this.coverImageUrl,
    this.isMember = false,
  });

  /// Works for:
  /// - /search
  /// - /search/popular-clubs
  factory ClubModel.fromMap(Map<String, dynamic> map) {
    return ClubModel(
      id: (map['id'] ?? map['uuid'] ?? '').toString(),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      membersCount: (map['membersCount'] ?? map['members_count'] ?? 0) is num
          ? (map['membersCount'] ?? map['members_count'] ?? 0).toInt()
          : 0,
      coverImageUrl: map['coverImageUrl'] ?? map['cover_image_url'],
      isMember: map['isMember'] == true,
    );
  }
}

class TagModel {
  final String id;
  final String name;
  final int usageCount;

  const TagModel({required this.id, required this.name, this.usageCount = 0});

  /// Works for:
  /// - /search
  /// - /search/trending-tags
  factory TagModel.fromMap(Map<String, dynamic> map) {
    return TagModel(
      id: (map['id'] ?? '').toString(),
      name: map['name'] ?? '',
      usageCount:
          (map['usageCount'] as num?)?.toInt() ??
          (map['usage_count'] as num?)?.toInt() ??
          0,
    );
  }
}
