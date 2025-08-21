class UserModel {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final int followersCount;
  final bool isFollowing;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.followersCount = 0,
    this.isFollowing = false,
  });
}

class ClubModel {
  final String id;
  final String name;
  final String description;
  final int membersCount;
  final String? coverImageUrl;
  final bool isMember;

  ClubModel({
    required this.id,
    required this.name,
    required this.description,
    required this.membersCount,
    this.coverImageUrl,
    this.isMember = false,
  });
}

class TagModel {
  final String id;
  final String name;
  final int usageCount;

  TagModel({required this.id, required this.name, this.usageCount = 0});
}
