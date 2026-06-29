// lib/features/post_view/presentation/pages/comments_page.dart
//
// VISUAL REFINEMENT — same design language as feed/post_view redesign.
// NO functional changes: same cubit calls, same pagination trigger,
// same reply sheet flow. Only colors, spacing, borders, and the loading
// shimmer changed (Skeletonizer → ShimmerScope/ShimmerBone, real motion).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/post_view/presentation/widgets/skeleton_line_plus.dart';
import '../../domain/entities/comment.dart';
import '../cubit/post_cubit.dart';

class _C {
  static const bg = Color(0xFF05060F);
  static const surface = Color(0xFF0E1024);
  static const border = Color(0xFF1A1D3D);
  static const accent = Color(0xFFFF6A00);
  static const textSecondary = Color(0xFF8B8FB8);
}

class CommentsPage extends StatelessWidget {
  const CommentsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PostCubit>();
    final comments = cubit.state.comments;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Comments',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70),
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
            cubit.loadMoreComments();
          }
          return false;
        },
        child: (cubit.state.loading && comments.isEmpty)
            ? const _CommentsShimmer()
            : comments.isEmpty
                ? const _EmptyComments()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    itemCount: comments.length + (cubit.state.commentsLoading ? 1 : 0),
                    separatorBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Container(height: 1, color: _C.border),
                    ),
                    itemBuilder: (_, i) {
                      if (i >= comments.length) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          child: _LoadingMoreRow(),
                        );
                      }
                      return _CommentTile(c: comments[i]);
                    },
                  ),
      ),
      bottomNavigationBar: _CommentInput(
        onSubmit: (t) => context.read<PostCubit>().addComment(t),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────
class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.surface,
                border: Border.all(color: _C.border),
              ),
              child: const Icon(Icons.mode_comment_rounded, color: _C.accent, size: 26),
            ),
            const SizedBox(height: 16),
            const Text(
              'No comments yet',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Start the conversation.',
              style: TextStyle(color: _C.textSecondary, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading-more footer row ────────────────────────────────────────────────
class _LoadingMoreRow extends StatelessWidget {
  const _LoadingMoreRow();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: _C.accent),
      ),
    );
  }
}

// ── Shimmer loading state — real motion, ShimmerScope/ShimmerBone ─────────
class _CommentsShimmer extends StatelessWidget {
  const _CommentsShimmer();
  @override
  Widget build(BuildContext context) {
    return ShimmerScope(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: 8,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(height: 1, color: _C.border),
        ),
        itemBuilder: (_, __) => const _MiniRowShimmer(),
      ),
    );
  }
}

class _MiniRowShimmer extends StatelessWidget {
  const _MiniRowShimmer();
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShimmerCircle(radius: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerBone(height: 12, width: 100),
              SizedBox(height: 7),
              ShimmerBone(height: 12, widthFactor: 1),
              SizedBox(height: 5),
              ShimmerBone(height: 12, widthFactor: 0.4),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Role pill — accent-tinted, matches feed/post-view ──────────────────────
class _RolePillTinted extends StatelessWidget {
  final String label;
  const _RolePillTinted({required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _C.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(color: _C.accent, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  final Comment c;
  const _CommentTile({required this.c});
  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _expanded = true;

  void _openReplySheet(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.border),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      'https://i.pravatar.cc/150?img=5',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _C.border),
                    ),
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Write a reply…',
                        hintStyle: TextStyle(color: _C.textSecondary, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    context.read<PostCubit>().addReply(widget.c.id, text);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _C.accent, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _C.border, width: 1.5),
              ),
              child: ClipOval(
                child: Image.network(
                  c.user.avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _C.accent.withOpacity(0.16),
                    child: const Icon(Icons.person_rounded, color: Colors.white70),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.user.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                      ),
                      if (c.user.roleLabel.isNotEmpty) _RolePillTinted(label: c.user.roleLabel),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(c.text, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        timeAgo(DateTime.now().difference(c.createdAt)),
                        style: const TextStyle(color: _C.textSecondary, fontSize: 11.5),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () => context.read<PostCubit>().toggleCommentLike(c.id),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Icon(
                              c.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 14,
                              color: c.isLiked ? _C.accent : _C.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${c.likes}',
                              style: TextStyle(
                                color: c.isLiked ? _C.accent : _C.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () => _openReplySheet(context),
                        child: const Text(
                          'Reply',
                          style: TextStyle(color: _C.accent, fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (c.replies.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Row(
                        children: [
                          Container(width: 18, height: 1, color: _C.border),
                          const SizedBox(width: 8),
                          Text(
                            _expanded ? 'Hide replies (${c.replies.length})' : 'View replies (${c.replies.length})',
                            style: const TextStyle(color: _C.accent, fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (_expanded && c.replies.isNotEmpty) ...[
          const SizedBox(height: 12),
          Column(
            children: c.replies.map((r) {
              return Padding(
                padding: const EdgeInsets.only(left: 46, bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.border),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          r.user.avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: _C.accent.withOpacity(0.16),
                            child: const Icon(Icons.person_rounded, size: 14, color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.user.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(r.text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                          const SizedBox(height: 6),
                          Text(
                            timeAgo(DateTime.now().difference(r.createdAt)),
                            style: const TextStyle(color: _C.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Comment input bar ──────────────────────────────────────────────────────
class _CommentInput extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  const _CommentInput({required this.onSubmit});
  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: _C.surface,
          border: Border(top: BorderSide(color: _C.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _C.border),
              ),
              child: ClipOval(
                child: Image.network(
                  'https://i.pravatar.cc/150?img=5',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _C.bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _C.border),
                ),
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Write a comment...',
                    hintStyle: TextStyle(color: _C.textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                if (_ctrl.text.trim().isEmpty) return;
                widget.onSubmit(_ctrl.text.trim());
                _ctrl.clear();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _C.accent, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Local timeAgo helper (kept from original — same signature) ────────────
String timeAgo(Duration d) {
  if (d.inSeconds < 60) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${(d.inDays / 7).floor()}w';
}