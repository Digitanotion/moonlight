import 'package:moonlight/features/feed/domain/repositories/feed_repository.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:moonlight/features/post_view/domain/entities/user.dart';
import 'package:moonlight/features/profile_view/data/datasources/profile_remote_datasource.dart';
import 'package:moonlight/features/profile_view/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remote;
  ProfileRepositoryImpl(this.remote);

  @override
  Future<UserProfile> getUser(String uuid) async {
    final map = await remote.getUser(uuid);
    final d = (map['data'] as Map).cast<String, dynamic>();

    return UserProfile(
      uuid: '${d['uuid']}',
      handle: '@${d['user_slug']}',
      fullName: '${d['fullname'] ?? d['user_slug']}',
      avatarUrl: '${d['avatar_url'] ?? ''}',
      bio: '${d['bio'] ?? ''}',
      country: '${d['country'] ?? ''}',
      followers: (d['followers_count'] as num?)?.toInt() ?? 0,
      following: (d['following_count'] as num?)?.toInt() ?? 0,
      isFollowing: d['is_following'] == true,
    );
  }

  @override
  Future<UserProfile> followUser(String uuid) async {
    final map = await remote.followUser(uuid);

    return UserProfile(
      uuid: uuid,
      handle: '',
      fullName: '',
      avatarUrl: '',
      bio: '',
      country: '',
      followers: (map['followers_count'] as num?)?.toInt() ?? 0,
      following: (map['following_count'] as num?)?.toInt() ?? 0,
      isFollowing: true,
    );
  }

  @override
  Future<UserProfile> unfollowUser(String uuid) async {
    final map = await remote.unfollowUser(uuid);

    return UserProfile(
      uuid: uuid,
      handle: '',
      fullName: '',
      avatarUrl: '',
      bio: '',
      country: '',
      followers: (map['followers_count'] as num?)?.toInt() ?? 0,
      following: 0,
      isFollowing: false,
    );
  }

  @override
  Future<Paginated<Post>> getUserPosts(
    String uuid, {
    int page = 1,
    int perPage = 20,
  }) async {
    final map = await remote.getUserPosts(uuid, page: page, perPage: perPage);
    final dataList = (map['data'] as List).cast<Map<String, dynamic>>();

    final posts = dataList.map<Post>((m) {
      final au = (m['author'] as Map).cast<String, dynamic>();
      final user = AppUser(
        id: "0",
        name: '${au['name']}',
        avatarUrl: '${au['avatarUrl']}',
        countryFlagEmoji: '${au['countryFlagEmoji']}',
        roleLabel: '${au['roleLabel']}',
        roleColor: '${au['roleColor']}',
      );

      return Post(
        id: '${m['uuid'] ?? m['id']}',
        author: user,
        mediaUrl: '${m['mediaUrl']}',
        caption: '${m['caption']}',
        tags: (m['tags'] as List).map((e) => '$e').toList(),
        createdAt: DateTime.tryParse('${m['createdAt']}') ?? DateTime.now(),
        likes: (m['likes'] as num?)?.toInt() ?? 0,
        commentsCount: (m['commentsCount'] as num?)?.toInt() ?? 0,
        shares: (m['shares'] as num?)?.toInt() ?? 0,
        isLiked: m['isLiked'] == true,
        views: (m['views'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final meta = (map['meta'] as Map).cast<String, dynamic>();
    final current = (meta['current_page'] as num?)?.toInt() ?? page;
    final last = (meta['last_page'] as num?)?.toInt() ?? page;

    return Paginated<Post>(data: posts, currentPage: current, lastPage: last);
  }
}
