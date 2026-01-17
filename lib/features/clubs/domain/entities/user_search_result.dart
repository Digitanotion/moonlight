class UserSearchResult {
  final String uuid;
  final String slug;
  final String email;
  final String fullname;
  final String? avatarUrl;

  UserSearchResult({
    required this.uuid,
    required this.slug,
    required this.email,
    required this.fullname,
    this.avatarUrl,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      uuid: json['uuid'] as String,
      slug: json['user_slug'] as String,
      email: json['email'] as String,
      fullname: json['fullname'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
