import 'package:bloc/bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/services/like_memory.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/post_repository.dart';

class PostState {
  final Post? post;
  final List<Comment> comments;
  final bool loading;
  final String? error;

  // Paging
  final bool commentsLoading;
  final bool commentsHasNext;
  final int commentsPage;

  const PostState({
    this.post,
    this.comments = const [],
    this.loading = false,
    this.error,
    this.commentsLoading = false,
    this.commentsHasNext = false,
    this.commentsPage = 1,
  });

  PostState copyWith({
    Post? post,
    List<Comment>? comments,
    bool? loading,
    String? error,
    bool? commentsLoading,
    bool? commentsHasNext,
    int? commentsPage,
  }) => PostState(
    post: post ?? this.post,
    comments: comments ?? this.comments,
    loading: loading ?? this.loading,
    error: error ?? this.error, // <-- keep previous error if not provided
    commentsLoading: commentsLoading ?? this.commentsLoading,
    commentsHasNext: commentsHasNext ?? this.commentsHasNext,
    commentsPage: commentsPage ?? this.commentsPage,
  );
}

class PostCubit extends Cubit<PostState> {
  final PostRepository repo;
  final String postId;
  bool _liking = false; // debounce

  PostCubit(this.repo, this.postId) : super(const PostState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      // final post = await repo.getPost(postId);
      // final page1 = await repo.getComments(postId, page: 1, perPage: 50);
      final mem = GetIt.I<LikeMemory>();
      final post = await repo.getPost(postId);
      final hydrated = mem.isLiked(post.id)
          ? post.copyWith(isLiked: true)
          : post;
      final page1 = await repo.getComments(postId, page: 1, perPage: 50);
      emit(
        PostState(
          post: hydrated,
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
    emit(state.copyWith(commentsLoading: true));
    try {
      final nextPage = state.commentsPage + 1;
      final res = await repo.getComments(postId, page: nextPage, perPage: 50);
      emit(
        state.copyWith(
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
    // optimistic
    final p = state.post!;
    final optimistic = p.copyWith(
      isLiked: !p.isLiked,
      likes: p.isLiked ? (p.likes - 1) : (p.likes + 1),
    );
    emit(state.copyWith(post: optimistic));
    try {
      final updated = await repo.toggleLike(postId);
      emit(state.copyWith(post: updated));
      GetIt.I<LikeMemory>().setLiked(postId, updated.isLiked);
      emit(state.copyWith(post: updated));
    } catch (e) {
      // rollback
      emit(state.copyWith(post: p));
    } finally {
      _liking = false;
    }
  }

  Future<void> addComment(String text) async {
    try {
      await repo.addComment(postId, text);
      // Refresh both post & first comments page to get updated counts
      final post = await repo.getPost(postId);
      final page1 = await repo.getComments(postId, page: 1, perPage: 50);
      emit(
        state.copyWith(
          post: post,
          comments: page1.data,
          commentsHasNext: page1.hasNext,
          commentsPage: page1.currentPage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: _friendly(e.toString())));
    }
  }

  Future<void> editCaption(String caption) async {
    try {
      final p = await repo.editCaption(postId, caption);
      emit(state.copyWith(post: p));
    } catch (e) {
      emit(state.copyWith(error: _friendly(e.toString())));
    }
  }

  Future<void> deletePost() async {
    try {
      await repo.deletePost(postId);
      emit(const PostState()); // caller should pop
    } catch (e) {
      emit(state.copyWith(error: _friendly(e.toString())));
    }
  }

  Future<void> addReply(String commentId, String text) async {
    try {
      await repo.addReply(postId, commentId, text);
      final page1 = await repo.getComments(postId, page: 1, perPage: 50);
      emit(
        state.copyWith(
          comments: page1.data,
          commentsHasNext: page1.hasNext,
          commentsPage: page1.currentPage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: _friendly(e.toString())));
    }
  }

  Future<void> toggleCommentLike(String commentId) async {
    try {
      final likes = await repo.toggleCommentLike(postId, commentId);
      final list = [...state.comments];
      if (_applyLike(list, commentId, likes)) {
        emit(state.copyWith(comments: list));
      }
    } catch (_) {
      // ignore or surface error if you prefer
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
