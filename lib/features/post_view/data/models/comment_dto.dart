import '../../domain/entities/comment.dart';
import 'user_dto.dart';

class CommentDto {
  final String id;
  final AppUserDto user;
  final String text;
  final DateTime createdAt;
  final int likes;
  final List<CommentDto> replies;

  CommentDto({
    required this.id,
    required this.user,
    required this.text,
    required this.createdAt,
    required this.likes,
    required this.replies,
  });

  factory CommentDto.fromMap(Map<String, dynamic> m) => CommentDto(
    id: '${m['id']}',
    user: AppUserDto.fromMap((m['user'] as Map).cast<String, dynamic>()),
    text: '${m['text'] ?? ''}',
    createdAt: DateTime.tryParse('${m['createdAt']}') ?? DateTime.now(),
    likes: (m['likes'] as num?)?.toInt() ?? 0,
    replies: ((m['replies'] as List?) ?? const [])
        .map((r) => CommentDto.fromMap((r as Map).cast<String, dynamic>()))
        .toList(),
  );

  Comment toEntity() => Comment(
    id: id,
    user: user.toEntity(),
    text: text,
    createdAt: createdAt,
    likes: likes,
    replies: replies.map((e) => e.toEntity()).toList(),
  );

  static CommentDto fromEntity(Comment c) => CommentDto(
    id: c.id,
    user: AppUserDto(
      uuid: c.user.id.toString(),
      slug: '',
      name: c.user.name,
      avatarUrl: c.user.avatarUrl,
      countryFlagEmoji: c.user.countryFlagEmoji,
      roleLabel: c.user.roleLabel,
      roleColor: c.user.roleColor,
    ),
    text: c.text,
    createdAt: c.createdAt,
    likes: c.likes,
    replies: c.replies.map(CommentDto.fromEntity).toList(),
  );
}
