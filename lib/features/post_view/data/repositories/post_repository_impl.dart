import '../../domain/entities/comment.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/post_remote_datasource.dart';

class PostRepositoryImpl implements PostRepository {
  final PostRemoteDataSource remote;
  PostRepositoryImpl(this.remote);

  @override
  Future<Post> getPost(String id) async =>
      (await remote.getPost(id)).toEntity();

  @override
  Future<Post> editCaption(String postId, String caption) async =>
      (await remote.editCaption(postId, caption)).toEntity();

  @override
  Future<void> deletePost(String postId) => remote.deletePost(postId);

  @override
  Future<Post> toggleLike(String postId) async =>
      (await remote.toggleLike(postId)).toEntity();
  @override
  Future<int> share(String postId) => remote.share(postId);

  @override
  Future<void> report(String postId, String reason) =>
      remote.report(postId, reason);

  @override
  Future<CommentsPageResult> getComments(
    String postId, {
    int page = 1,
    int perPage = 50,
  }) => remote.getComments(postId, page: page, perPage: perPage);

  @override
  Future<Comment> addComment(String postId, String text) =>
      remote.addComment(postId, text);

  @override
  Future<Comment> addReply(String postId, String commentId, String text) =>
      remote.addReply(postId, commentId, text);

  /// Now returns updated likes count
  @override
  Future<int> toggleCommentLike(String postId, String commentId) =>
      remote.toggleCommentLike(postId, commentId);
}
