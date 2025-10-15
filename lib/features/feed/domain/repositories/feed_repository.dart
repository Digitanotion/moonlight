import 'package:moonlight/features/post_view/domain/entities/post.dart';

class Paginated<T> {
  final List<T> data;
  final int currentPage;
  final int lastPage;
  final bool hasMore;
  Paginated({
    required this.data,
    required this.currentPage,
    required this.lastPage,
  }) : hasMore = currentPage < lastPage;
}

abstract class FeedRepository {
  Future<Paginated<Post>> fetchFeed({int page, int perPage});
  Future<Post> toggleLike(String postUuid);
  Future<int> share(String postUuid);
}
