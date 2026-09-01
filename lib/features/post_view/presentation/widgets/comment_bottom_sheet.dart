// lib/features/post_view/presentation/widgets/comment_bottom_sheet.dart
//
// Reusable comment sheet — lets a user view, add, reply to, and like
// comments without navigating away from wherever they currently are
// (feed card, video feed screen, etc). Wraps the existing PostCubit
// (already has getComments/addComment/addReply/toggleCommentLike —
// nothing new needed at the data layer, just this presentation).
// Doc item 6: "the image or video doesn't need to open before comments
// or likes can be made."

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/utils/time_ago.dart';
import 'package:moonlight/features/post_view/domain/entities/comment.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:moonlight/features/post_view/domain/repositories/post_repository.dart';
import 'package:moonlight/features/post_view/presentation/cubit/post_cubit.dart';

class CommentBottomSheet {
  /// [onCountChanged] fires with the current comment total whenever it moves
  /// (add / delete), so the caller — a feed card, the video feed — can keep
  /// its own count in sync without a full refresh.
  static Future<void> show(
    BuildContext context, {
    required String postId,
    Post? initialPost,
    void Function(int newCount)? onCountChanged,
  }) {
    PostCubit build() {
      try {
        final cubit = sl<PostCubit>(param1: postId, param2: initialPost);
        if (initialPost == null) cubit.load();
        return cubit;
      } catch (e) {
        debugPrint('❌ GetIt factory param failed: $e');
        final cubit =
            PostCubit(sl<PostRepository>(), postId, initialPost: initialPost);
        if (initialPost == null) cubit.load();
        return cubit;
      }
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider<PostCubit>(
        create: (_) => build(),
        child: _CommentSheetBody(onCountChanged: onCountChanged),
      ),
    );
  }
}

class _CommentSheetBody extends StatefulWidget {
  const _CommentSheetBody({this.onCountChanged});
  final void Function(int newCount)? onCountChanged;

  @override
  State<_CommentSheetBody> createState() => _CommentSheetBodyState();
}

class _CommentSheetBodyState extends State<_CommentSheetBody> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Comment? _replyingTo;
  int? _lastReportedCount;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _maybeReportCount(int? count) {
    if (count == null || count == _lastReportedCount) return;
    _lastReportedCount = count;
    widget.onCountChanged?.call(count);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<PostCubit>().loadMoreComments();
    }
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    if (_replyingTo != null) {
      context.read<PostCubit>().addReply(_replyingTo!.id, text);
    } else {
      context.read<PostCubit>().addComment(text);
    }
    _inputCtrl.clear();
    setState(() => _replyingTo = null);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PostCubit, PostState>(
      listenWhen: (p, n) => p.post?.commentsCount != n.post?.commentsCount,
      listener: (_, state) => _maybeReportCount(state.post?.commentsCount),
      child: _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sheetScrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E1024),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            BlocBuilder<PostCubit, PostState>(
              buildWhen: (p, n) => p.post?.commentsCount != n.post?.commentsCount,
              builder: (context, state) => Text(
                'Comments${state.post != null ? ' (${state.post!.commentsCount})' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: BlocBuilder<PostCubit, PostState>(
                builder: (context, state) {
                  if (state.loading && state.comments.isEmpty) {
                    return const _CommentsShimmer();
                  }
                  if (state.comments.isEmpty) {
                    return const Center(
                      child: Text(
                        'No comments yet — be the first!',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: sheetScrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: state.comments.length,
                    itemBuilder: (context, i) => _CommentTile(
                      comment: state.comments[i],
                      onReply: (c) => setState(() => _replyingTo = c),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_replyingTo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              'Replying to ${_replyingTo!.user.name}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() => _replyingTo = null),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: _replyingTo != null
                                  ? 'Write a reply...'
                                  : 'Add a comment...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded,
                              color: Color(0xFFFF6A00)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder shown while the first page of comments is loading — a few
/// greyed rows pulsing, so the user sees work is happening rather than a
/// bare spinner or an empty sheet.
class _CommentsShimmer extends StatelessWidget {
  const _CommentsShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.08),
      highlightColor: Colors.white.withOpacity(0.18),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 7,
        itemBuilder: (context, i) {
          final double lineWidth = (i.isEven ? 0.82 : 0.55);
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(radius: 15, backgroundColor: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FractionallySizedBox(
                        widthFactor: lineWidth,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final ValueChanged<Comment> onReply;
  final bool isReply;

  const _CommentTile({
    required this.comment,
    required this.onReply,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 36 : 0,
        top: 10,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: isReply ? 12 : 15,
                backgroundColor: Colors.white10,
                backgroundImage: comment.user.avatarUrl.isNotEmpty
                    ? NetworkImage(comment.user.avatarUrl)
                    : null,
                child: comment.user.avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 14, color: Colors.white38)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgoFrom(comment.createdAt),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comment.text,
                      style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              context.read<PostCubit>().toggleCommentLike(comment.id),
                          child: Row(
                            children: [
                              Icon(
                                comment.isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 14,
                                color: comment.isLiked
                                    ? const Color(0xFFFF6A00)
                                    : Colors.white38,
                              ),
                              if (comment.likes > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${comment.likes}',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (!isReply)
                          GestureDetector(
                            onTap: () => onReply(comment),
                            child: const Text(
                              'Reply',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.replies.isNotEmpty)
            ...comment.replies.map(
              (r) => _CommentTile(comment: r, onReply: onReply, isReply: true),
            ),
        ],
      ),
    );
  }
}