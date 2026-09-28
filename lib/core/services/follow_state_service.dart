import 'dart:async';

/// App-wide broadcast of follow/unfollow actions.
///
/// Follow state is cached per-author on every `Post`/`AppUser` object
/// returned by the API (`isFollowing`), and there are several
/// *independent* `FeedCubit` instances alive at once — the Home "Watch"
/// video grid, the "Discover" mixed feed, and any hashtag/search-results
/// feed each construct their own (see injection_container.dart's
/// `registerFactory<FeedCubit>` and home_top_tabs.dart's separate
/// `_discoverCubit`/`_watchVideoCubit`). A follow made inside one of them
/// only patched that one cubit's own `state.items`, so the same author's
/// posts in every *other* already-loaded feed kept showing "Follow" even
/// though the user had already followed them — including the most common
/// path of all, the profile page's own Follow button, which didn't patch
/// any feed at all.
///
/// This is the single source of truth every follow/unfollow action reports
/// to, and every feed that caches `isFollowing` subscribes to, so one
/// follow anywhere is reflected everywhere.
class FollowStateService {
  FollowStateService._();
  static final FollowStateService instance = FollowStateService._();

  final _controller = StreamController<FollowChange>.broadcast();

  Stream<FollowChange> get changes => _controller.stream;

  /// Call after a successful follow/unfollow API call, from *any* screen —
  /// the profile page's Follow button, a follower/following list row, a
  /// video card's follow badge, etc.
  void notify(String authorId, bool isFollowing) {
    if (authorId.isEmpty) return;
    _controller.add(FollowChange(authorId, isFollowing));
  }
}

class FollowChange {
  final String authorId;
  final bool isFollowing;
  const FollowChange(this.authorId, this.isFollowing);
}
