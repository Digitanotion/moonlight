import 'package:moonlight/features/post_view/domain/entities/user.dart';

// lib/features/post_view/domain/entities/comment.dart

class Comment {
  final String id;
  final AppUser user;
  final String text;
  final DateTime createdAt;
  final int likes;
  final bool isLiked;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.user,
    required this.text,
    required this.createdAt,
    this.likes = 0,
    this.isLiked = false,
    this.replies = const [],
  });

  Comment copyWith({
    int? likes,
    bool? isLiked, // ← ADD THIS
    List<Comment>? replies,
  }) => Comment(
    id: id,
    user: user,
    text: text,
    createdAt: createdAt,
    likes: likes ?? this.likes,
    isLiked: isLiked ?? this.isLiked, // ← ADD THIS
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
