import 'package:moonlight/features/post_view/domain/entities/user.dart';

class Comment {
  final String id;
  final AppUser user;
  final String text;
  final DateTime createdAt;
  final int likes;
  final List<Comment> replies;
  const Comment({
    required this.id,
    required this.user,
    required this.text,
    required this.createdAt,
    this.likes = 0,
    this.replies = const [],
  });

  Comment copyWith({int? likes, List<Comment>? replies}) => Comment(
    id: id,
    user: user,
    text: text,
    createdAt: createdAt,
    likes: likes ?? this.likes,
    replies: replies ?? this.replies,
  );
}

// Paging wrapper for comments
class CommentsPageResult {
  final List<Comment> data;
  final int currentPage;
  final int perPage;
  final int total;
  final bool hasNext;

  const CommentsPageResult({
    required this.data,
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.hasNext,
  });

  CommentsPageResult copyWith({
    List<Comment>? data,
    int? currentPage,
    int? perPage,
    int? total,
    bool? hasNext,
  }) {
    return CommentsPageResult(
      data: data ?? this.data,
      currentPage: currentPage ?? this.currentPage,
      perPage: perPage ?? this.perPage,
      total: total ?? this.total,
      hasNext: hasNext ?? this.hasNext,
    );
  }
}
