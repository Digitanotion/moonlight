// lib/features/profile_view/domain/repositories/profile_repository.dart

import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/feed/domain/repositories/feed_repository.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';

class UserProfile {
  final String uuid;
  final String handle;
  final String fullName;
  final String avatarUrl;
  final String bio;
  final String country;
  final int followers;
  final int following;
  final bool isFollowing;
  final String? roleLabel;

  UserProfile({
    required this.uuid,
    required this.handle,
    required this.fullName,
    required this.avatarUrl,
    required this.bio,
    required this.country,
    required this.followers,
    required this.following,
    this.isFollowing = false,
    this.roleLabel = 'Nominal Member',
  });
}

// Lightweight club summary for profile display
class ProfileClub {
  final String uuid;
  final String slug;
  final String name;
  final String? avatarUrl;
  final String? description;
  final String? motto;
  final String? location;
  final int membersCount;
  final bool isPrivate;
  final bool isMember;
  final bool isCreator;
  final bool isAdmin;

  const ProfileClub({
    required this.uuid,
    this.slug = '',
    required this.name,
    this.avatarUrl,
    this.description,
    this.motto,
    this.location,
    this.membersCount = 0,
    this.isPrivate = false,
    this.isMember = false,
    this.isCreator = false,
    this.isAdmin = false,
  });

  /// The role to display on the club card, e.g. for a "Creator" or "Admin" badge.
  /// Returns null when the user is a plain member (or not a member at all),
  /// so the UI can skip rendering a badge in that case.
  String? get roleBadgeLabel {
    if (isCreator) return 'Creator';
    if (isAdmin) return 'Admin';
    return null;
  }

  factory ProfileClub.fromJson(Map<String, dynamic> j) {
    // Handle both direct fields and nested data wrapper
    final d = j.containsKey('data')
        ? (j['data'] as Map).cast<String, dynamic>()
        : j;

    return ProfileClub(
      uuid: '${d['uuid'] ?? d['id'] ?? ''}',
      slug: '${d['slug'] ?? ''}',
      name: '${d['name'] ?? ''}',
      // Backend (ClubResource) returns `coverImageUrl`; keep older
      // field names as fallbacks in case any endpoint still uses them.
      avatarUrl: d['coverImageUrl']?.toString() ??
          d['avatar_url']?.toString() ??
          d['logo_url']?.toString() ??
          d['image_url']?.toString(),
      description: d['description']?.toString() ?? d['bio']?.toString(),
      motto: d['motto']?.toString(),
      location: d['location']?.toString(),
      membersCount: (d['membersCount'] as num?)?.toInt() ??
          (d['members_count'] as num?)?.toInt() ??
          0,
      isPrivate: d['isPrivate'] == true || d['is_private'] == true,
      isMember: d['isMember'] == true || d['is_member'] == true,
      isCreator: d['isCreator'] == true || d['is_creator'] == true,
      isAdmin: d['isAdmin'] == true || d['is_admin'] == true,
    );
  }
}

abstract class ProfileRepository {
  Future<UserProfile> getUser(String uuid);
  Future<Paginated<Post>> getUserPosts(String uuid, {int page, int perPage});
  Future<UserProfile> followUser(String uuid);
  Future<UserProfile> unfollowUser(String uuid);
  Future<void> blockUser(String uuid, {String? reason});
  Future<List<ProfileClub>> getUserClubs(String uuid);
}