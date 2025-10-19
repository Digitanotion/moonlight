import '../entities/post.dart';
import '../entities/comment.dart';

abstract class PostRepository {
  Future<Post> getPost(String id);
  Future<Post> editCaption(String postId, String caption);
  Future<void> deletePost(String postId);
  Future<Post> toggleLike(String postId);
  Future<int> share(String postId);
  Future<void> report(String postId, String reason);

  Future<CommentsPageResult> getComments(
    String postId, {
    int page = 1,
    int perPage = 50,
  });
  Future<Comment> addComment(String postId, String text);
  Future<Comment> addReply(String postId, String commentId, String text);

  /// 🔄 updated signature
  Future<int> toggleCommentLike(String postId, String commentId);
  Future<Comment> editComment(String postId, String commentId, String text);
  Future<void> deleteComment(String postId, String commentId);
}
