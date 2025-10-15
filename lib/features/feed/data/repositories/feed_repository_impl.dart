import 'package:moonlight/features/feed/data/datasources/feed_remote_datasource.dart';
import 'package:moonlight/features/feed/domain/repositories/feed_repository.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:moonlight/features/post_view/domain/entities/user.dart';

class FeedRepositoryImpl implements FeedRepository {
  final FeedRemoteDataSource remote;
  FeedRepositoryImpl(this.remote);

  @override
  Future<Paginated<Post>> fetchFeed({int page = 1, int perPage = 20}) async {
    final map = await remote.fetchFeed(page: page, perPage: perPage);
    final dataList = (map['data'] as List).cast<Map<String, dynamic>>();
    final posts = dataList.map<Post>((m) {
      final au = (m['author'] as Map).cast<String, dynamic>();
      final user = AppUser(
        id: 0, // not used; use uuid/slug instead
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
        tags: (m['tags'] as List).cast<dynamic>().map((e) => '$e').toList(),
        createdAt: DateTime.tryParse('${m['createdAt']}') ?? DateTime.now(),
        likes: (m['likes'] as num?)?.toInt() ?? 0,
        commentsCount: (m['commentsCount'] as num?)?.toInt() ?? 0,
        shares: (m['shares'] as num?)?.toInt() ?? 0,
        isLiked: (m['isLiked'] == true),
        views: (m['views'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final meta = (map['meta'] as Map).cast<String, dynamic>();
    final current = (meta['current_page'] as num?)?.toInt() ?? page;
    final last = (meta['last_page'] as num?)?.toInt() ?? page;

    return Paginated<Post>(data: posts, currentPage: current, lastPage: last);
  }

  @override
  Future<Post> toggleLike(String postUuid) async {
    final res = await remote.toggleLike(postUuid);
    // API returns { liked: bool, likes: int }
    // We only need to reflect the count & liked flag; caller merges into existing Post.
    return Post(
      id: postUuid,
      author: const AppUser(
        id: 0,
        name: '',
        avatarUrl: '',
        countryFlagEmoji: '',
        roleLabel: '',
        roleColor: '#ADB5BD',
      ),
      mediaUrl: '',
      caption: '',
      tags: const [],
      createdAt: DateTime.now(),
      likes: (res['likes'] as num?)?.toInt() ?? 0,
      commentsCount: 0,
      shares: 0,
      isLiked: (res['liked'] == true),
    );
  }

  @override
  Future<int> share(String postUuid) async {
    final res = await remote.share(postUuid);
    return (res['shares'] as num?)?.toInt() ?? 0;
  }
}
