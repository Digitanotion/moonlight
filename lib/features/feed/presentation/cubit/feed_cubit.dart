import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/network/error_parser.dart';
import 'package:moonlight/core/services/like_memory.dart';
import 'package:moonlight/features/feed/domain/repositories/feed_repository.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';

class FeedState extends Equatable {
  final List<Post> items;
  final bool initialLoading;
  final bool paging;
  final String? error;
  final int page;
  final bool hasMore;

  const FeedState({
    this.items = const [],
    this.initialLoading = false,
    this.paging = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  FeedState copyWith({
    List<Post>? items,
    bool? initialLoading,
    bool? paging,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return FeedState(
      items: items ?? this.items,
      initialLoading: initialLoading ?? this.initialLoading,
      paging: paging ?? this.paging,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  List<Object?> get props => [
    items,
    initialLoading,
    paging,
    error,
    page,
    hasMore,
  ];
}

class FeedCubit extends Cubit<FeedState> {
  final FeedRepository repo;
  FeedCubit(this.repo) : super(const FeedState());

  static const _perPage = 20;

  // ---------- private helpers ----------
  Post _applyLocalLike(Post p) {
    final mem = GetIt.I<LikeMemory>();
    return mem.isLiked(p.id) ? p.copyWith(isLiked: true) : p;
  }

  // ---------- public API ----------
  Future<void> loadFirstPage() async {
    emit(state.copyWith(initialLoading: true, error: null, page: 1));
    try {
      final page1 = await repo.fetchFeed(page: 1, perPage: _perPage);
      final hydrated = page1.data.map(_applyLocalLike).toList();
      emit(
        state.copyWith(
          items: hydrated,
          initialLoading: false,
          page: 1,
          hasMore: page1.hasMore,
        ),
      );
    } catch (e) {
      emit(state.copyWith(initialLoading: false, error: apiErrorMessage(e)));
    }
  }

  Future<void> loadNextPage() async {
    if (state.paging || !state.hasMore || state.initialLoading) return;
    emit(state.copyWith(paging: true, error: null));
    try {
      final next = state.page + 1;
      final r = await repo.fetchFeed(page: next, perPage: _perPage);
      final hydrated = r.data.map(_applyLocalLike).toList();
      emit(
        state.copyWith(
          items: [...state.items, ...hydrated],
          paging: false,
          page: next,
          hasMore: r.hasMore,
        ),
      );
    } catch (e) {
      emit(state.copyWith(paging: false, error: apiErrorMessage(e)));
    }
  }

  Future<void> toggleLikeAt(int index) async {
    if (index < 0 || index >= state.items.length) return;
    final current = state.items[index];

    // 1) Optimistic update
    final optimistic = current.copyWith(
      isLiked: !current.isLiked,
      likes: current.isLiked
          ? (current.likes - 1).clamp(0, 1 << 31)
          : current.likes + 1,
    );
    emit(state.copyWith(items: [...state.items]..[index] = optimistic));

    try {
      // 2) Server reconciliation
      final serverPost = await repo.toggleLike(current.id);

      // If server returned weird counts (e.g., 0), prefer optimistic as a guard.
      final likes = (serverPost.likes <= 0 && optimistic.likes > 0)
          ? optimistic.likes
          : serverPost.likes;

      final merged = optimistic.copyWith(
        likes: likes,
        isLiked: serverPost.isLiked,
      );

      // 3) Persist final like state in memory
      final mem = GetIt.I<LikeMemory>();
      mem.setLiked(current.id, merged.isLiked);

      // 4) Emit final merged item
      emit(state.copyWith(items: [...state.items]..[index] = merged));
    } catch (e) {
      // Roll back on error
      emit(
        state.copyWith(
          items: [...state.items]..[index] = current,
          error: apiErrorMessage(e),
        ),
      );
    }
  }

  Future<void> shareAt(int index) async {
    if (index < 0 || index >= state.items.length) return;
    final current = state.items[index];
    final optimistic = current.copyWith(shares: current.shares + 1);
    emit(state.copyWith(items: [...state.items]..[index] = optimistic));
    try {
      final shares = await repo.share(current.id);
      emit(
        state.copyWith(
          items: [...state.items]
            ..[index] = optimistic.copyWith(shares: shares),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          items: [...state.items]..[index] = current,
          error: apiErrorMessage(e),
        ),
      );
    }
  }

  void incrementViewsAt(int index) {
    if (index < 0 || index >= state.items.length) return;
    final p = state.items[index];
    final upd = p.copyWith(views: p.views + 1);
    emit(state.copyWith(items: [...state.items]..[index] = upd));
  }

  /// Called when you return from PostView with an updated Post.
  void replaceAt(int index, Post updated) {
    if (index < 0 || index >= state.items.length) return;
    // keep memory in sync as well
    GetIt.I<LikeMemory>().setLiked(updated.id, updated.isLiked);
    final merged = _applyLocalLike(updated);
    emit(state.copyWith(items: [...state.items]..[index] = merged));
  }

  Future<void> refresh() => loadFirstPage();
}
