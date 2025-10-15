import 'package:moonlight/features/feed/domain/repositories/feed_repository.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';

class UserProfile {
  final String uuid;
  final String handle; // user_slug
  final String fullName; // fullname or name
  final String avatarUrl;
  final String bio;
  final String country;
  final int followers;
  final int following;

  UserProfile({
    required this.uuid,
    required this.handle,
    required this.fullName,
    required this.avatarUrl,
    required this.bio,
    required this.country,
    required this.followers,
    required this.following,
  });
}

abstract class ProfileRepository {
  Future<UserProfile> getUser(String uuid);
  Future<Paginated<Post>> getUserPosts(String uuid, {int page, int perPage});
}
