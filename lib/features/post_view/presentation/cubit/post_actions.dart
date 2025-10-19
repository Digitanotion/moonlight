// lib/features/post_view/presentation/cubit/post_actions.dart
import '../../domain/entities/comment.dart';
import '../../domain/entities/post.dart';

abstract class PostAction {
  const PostAction();
}

// Success
class CommentAdded extends PostAction {
  final Comment comment;
  const CommentAdded(this.comment);
}

class CommentEdited extends PostAction {
  final Comment comment;
  const CommentEdited(this.comment);
}

class CommentDeleted extends PostAction {
  final String commentId;
  const CommentDeleted(this.commentId);
}

class ReplyAdded extends PostAction {
  final Comment reply;
  const ReplyAdded(this.reply);
}

class ReplyEdited extends PostAction {
  final Comment reply;
  const ReplyEdited(this.reply);
}

class ReplyDeleted extends PostAction {
  final String replyId;
  const ReplyDeleted(this.replyId);
}

class PostEdited extends PostAction {
  final Post post;
  const PostEdited(this.post);
}

class PostDeleted extends PostAction {
  const PostDeleted();
}

// Failure
class ActionFailed extends PostAction {
  final String message;
  const ActionFailed(this.message);
}
