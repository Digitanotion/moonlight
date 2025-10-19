// lib/features/post_view/presentation/cubit/post_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/services/like_memory.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/post_repository.dart';
import 'post_actions.dart';

class PostState {
  final Post? post;
  final List<Comment> comments;
  final bool loading;
  final String? error;

  // Paging
  final bool commentsLoading;
  final bool commentsHasNext;
  final int commentsPage;

  // One-shot action feedback
  final PostAction? lastAction;

  // Operation flags
  final bool deletingPost;
  final Set<String> deletingCommentIds;

  const PostState({
    this.post,
    this.comments = const [],
    this.loading = false,
    this.error,
    this.commentsLoading = false,
    this.commentsHasNext = false,
    this.commentsPage = 1,
    this.lastAction,
    this.deletingPost = false,
    this.deletingCommentIds = const {},
  });

  PostState copyWith({
    Post? post,
    List<Comment>? comments,
    bool? loading,
    String? error,
    bool? commentsLoading,
    bool? commentsHasNext,
    int? commentsPage,
    PostAction? lastAction, // pass null explicitly to clear
    bool? deletingPost,
    Set<String>? deletingCommentIds,
  }) => PostState(
    post: post ?? this.post,
    comments: comments ?? this.comments,
    loading: loading ?? this.loading,
    error: error ?? this.error,
    commentsLoading: commentsLoading ?? this.commentsLoading,
    commentsHasNext: commentsHasNext ?? this.commentsHasNext,
    commentsPage: commentsPage ?? this.commentsPage,
    lastAction: lastAction,
    deletingPost: deletingPost ?? this.deletingPost,
    deletingCommentIds: deletingCommentIds ?? this.deletingCommentIds,
  );
}

class PostCubit extends Cubit<PostState> {
  final PostRepository repo;
  final String postId;
  bool _liking = false; // debounce

  PostCubit(this.repo, this.postId) : super(const PostState());

  /// clear one-shot action
  void consumeAction() {
    if (state.lastAction != null) {
      emit(state.copyWith(lastAction: null));
    }
  }

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null, lastAction: null));
    try {
      final mem = GetIt.I<LikeMemory>();
      final post = await repo.getPost(postId);
      final hydrated = mem.isLiked(post.id)
          ? post.copyWith(isLiked: true)
          : post;

      // fetch first comments page; CommentsPageResult.total will prefer
      // total_comments_and_replies if the API provides it (see datasource).
      final page1 = await repo.getComments(postId, page: 1, perPage: 50);

      // Keep post.commentsCount in sync with page total (combined comments+replies)
      final updatedPost = hydrated.copyWith(commentsCount: page1.total);

      emit(
        PostState(
          post: updatedPost,
          comments: page1.data,
          loading: false,
          commentsLoading: false,
          commentsHasNext: page1.hasNext,
          commentsPage: page1.currentPage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _friendly(e.toString())));
    }
  }

  Future<void> loadMoreComments() async {
    if (state.commentsLoading || !state.commentsHasNext) return;
    emit(state.copyWith(commentsLoading: true, lastAction: null));
    try {
      final nextPage = state.commentsPage + 1;
      final res = await repo.getComments(postId, page: nextPage, perPage: 50);

      // sync post commentsCount with backend's page total (may be combined)
      final updatedPost =
          state.post?.copyWith(commentsCount: res.total) ?? state.post;

      emit(
        state.copyWith(
          post: updatedPost,
          comments: [...state.comments, ...res.data],
          commentsLoading: false,
          commentsHasNext: res.hasNext,
          commentsPage: res.currentPage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(commentsLoading: false));
    }
  }

  Future<void> toggleLike() async {
    if (_liking || state.post == null) return;
    _liking = true;
    final p = state.post!;
    // optimistic update
    final optimistic = p.copyWith(
      isLiked: !p.isLiked,
      likes: p.isLiked ? (p.likes - 1) : (p.likes + 1),
    );
    emit(state.copyWith(post: optimistic, lastAction: null));
    try {
      final updated = await repo.toggleLike(postId);
      // repo returns full post — trust it as source of truth
      emit(state.copyWith(post: updated));
      GetIt.I<LikeMemory>().setLiked(postId, updated.isLiked);
      // emit again to ensure listeners get latest
      emit(state.copyWith(post: updated));
    } catch (e) {
      // rollback on error
      emit(state.copyWith(post: p));
    } finally {
      _liking = false;
    }
  }

  Future<void> addComment(String text) async {
    try {
      final created = await repo.addComment(postId, text);
      // Refresh both post & first comments page to get updated counts
      final post = await repo.getPost(postId);
      final page1 = await repo.getComments(postId, page: 1, perPage: 50);

      // sync post commentsCount to page total
      final updatedPost = post.copyWith(commentsCount: page1.total);

      emit(
        state.copyWith(
          post: updatedPost,
          comments: page1.data,
          commentsHasNext: page1.hasNext,
          commentsPage: page1.currentPage,
          lastAction: CommentAdded(created),
        ),
      );
    } catch (e) {
      final msg = _friendly(e.toString());
      emit(state.copyWith(error: msg, lastAction: ActionFailed(msg)));
    }
  }

  Future<void> editCaption(String caption) async {
    try {
      emit(state.copyWith(loading: true, error: null, lastAction: null));
      final p = await repo.editCaption(postId, caption);
      emit(state.copyWith(post: p, loading: false, lastAction: PostEdited(p)));
    } catch (e) {
      final msg = _friendly(e.toString());
      emit(
        state.copyWith(
          loading: false,
          error: msg,
          lastAction: ActionFailed(msg),
        ),
      );
      rethrow;
    }
  }

  Future<void> deletePost() async {
    if (state.deletingPost) return;
    emit(state.copyWith(deletingPost: true, lastAction: null));
    try {
      await repo.deletePost(postId);
      // emit a fresh empty state with PostDeleted action
      emit(const PostState(lastAction: PostDeleted()));
    } catch (e) {
      final msg = _friendly(e.toString());
      emit(
        state.copyWith(
          deletingPost: false,
          error: msg,
          lastAction: ActionFailed(msg),
        ),
      );
      rethrow;
    }
  }

  Future<void> addReply(String commentId, String text) async {
    try {
      final created = await repo.addReply(postId, commentId, text);
      // Re-fetch first page to get updated comment list & combined count
      final page1 = await repo.getComments(postId, page: 1, perPage: 50);
      final updatedPost =
          state.post?.copyWith(commentsCount: page1.total) ?? state.post;

      emit(
        state.copyWith(
          post: updatedPost,
          comments: page1.data,
          commentsHasNext: page1.hasNext,
          commentsPage: page1.currentPage,
          lastAction: ReplyAdded(created),
        ),
      );
    } catch (e) {
      final msg = _friendly(e.toString());
      emit(state.copyWith(error: msg, lastAction: ActionFailed(msg)));
    }
  }

  Future<void> toggleCommentLike(String commentId) async {
    try {
      final likes = await repo.toggleCommentLike(postId, commentId);
      final list = [...state.comments];
      if (_applyLike(list, commentId, likes)) {
        emit(state.copyWith(comments: list, lastAction: null));
      }
    } catch (_) {
      // ignore silently
    }
  }

  Future<void> editComment(String commentId, String text) async {
    try {
      final updated = await repo.editComment(postId, commentId, text);
      // Refresh page1 to reflect edit and keep totals in sync
      final page1 = await repo.getComments(postId, page: 1, perPage: 50);
      final updatedPost =
          state.post?.copyWith(commentsCount: page1.total) ?? state.post;

      emit(
        state.copyWith(
          post: updatedPost,
          comments: page1.data,
          commentsHasNext: page1.hasNext,
          commentsPage: page1.currentPage,
          lastAction: CommentEdited(updated),
        ),
      );
    } catch (e) {
      final msg = _friendly(e.toString());
      emit(state.copyWith(error: msg, lastAction: ActionFailed(msg)));
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId) async {
    if (state.deletingCommentIds.contains(commentId)) return;
    final nextIds = {...state.deletingCommentIds}..add(commentId);
    emit(state.copyWith(deletingCommentIds: nextIds, lastAction: null));
    try {
      await repo.deleteComment(postId, commentId);
      final page1 = await repo.getComments(postId, page: 1, perPage: 50);
      final after = {...state.deletingCommentIds}..remove(commentId);
      final updatedPost =
          state.post?.copyWith(commentsCount: page1.total) ?? state.post;

      emit(
        state.copyWith(
          post: updatedPost,
          comments: page1.data,
          commentsHasNext: page1.hasNext,
          commentsPage: page1.currentPage,
          deletingCommentIds: after,
          lastAction: CommentDeleted(commentId),
        ),
      );
    } catch (e) {
      final after = {...state.deletingCommentIds}..remove(commentId);
      final msg = _friendly(e.toString());
      emit(
        state.copyWith(
          deletingCommentIds: after,
          error: msg,
          lastAction: ActionFailed(msg),
        ),
      );
      rethrow;
    }
  }

  bool _applyLike(List<Comment> list, String id, int likes) {
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == id) {
        list[i] = list[i].copyWith(likes: likes);
        return true;
      }
      final child = [...list[i].replies];
      final ok = _applyLike(child, id, likes);
      if (ok) {
        list[i] = list[i].copyWith(replies: child);
        return true;
      }
    }
    return false;
  }

  String _friendly(String raw) {
    if (raw.contains('401')) return 'Login required.';
    if (raw.contains('403')) return "You don't have permission for that.";
    if (raw.contains('404')) return 'Resource not found.';
    if (raw.contains('422')) return 'Validation failed.';
    return 'Something went wrong. Please try again.';
  }
}
