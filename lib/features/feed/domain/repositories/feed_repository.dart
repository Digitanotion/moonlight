// lib/features/feed/domain/repositories/feed_repository.dart

import 'package:moonlight/features/post_view/domain/entities/post.dart';

class Paginated<T> {
  final List<T> data;
  final int currentPage;
  final int lastPage;

  const Paginated({
    required this.data,
    required this.currentPage,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;
}

abstract class FeedRepository {
  Future<Paginated<Post>> fetchFeed({int page = 1, int perPage = 20});
  Future<Post> toggleLike(String postUuid);
  Future<int> share(String postUuid);
  Future<int> recordView(String postUuid);
}