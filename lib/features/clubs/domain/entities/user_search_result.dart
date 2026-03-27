// lib/features/clubs/domain/entities/user_search_result.dart

class UserSearchResult {
  final String uuid;
  final String slug;
  final String email;
  final String? fullname; // Make this nullable
  final String? avatarUrl;

  UserSearchResult({
    required this.uuid,
    required this.slug,
    required this.email,
    this.fullname, // Now optional
    this.avatarUrl,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      uuid: json['uuid'] as String,
      slug: json['user_slug'] as String,
      email: json['email'] as String,
      fullname: json['fullname'] as String?, // Handle null
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  // Helper method to get display name with fallback
  String get displayName => fullname ?? email.split('@').first;
}
