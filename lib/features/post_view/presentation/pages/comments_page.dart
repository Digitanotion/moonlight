import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/post_view/presentation/widgets/skeleton_line_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_ago.dart';
import '../../domain/entities/comment.dart';
import '../cubit/post_cubit.dart';
import '../widgets/chips.dart';

class CommentsPage extends StatelessWidget {
  const CommentsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PostCubit>();
    final comments = cubit.state.comments;

    return Scaffold(
      backgroundColor: AppColors.navyDark,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: Text('Comments', style: AppTextStyles.titleMedium),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
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
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount:
                    comments.length + (cubit.state.commentsLoading ? 1 : 0),
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.divider, height: 28),
                itemBuilder: (_, i) {
                  if (i >= comments.length) {
                    // pagination footer shimmer
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: _MiniRowShimmer(),
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

class _CommentsShimmer extends StatelessWidget {
  const _CommentsShimmer();
  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 10,
        separatorBuilder: (_, __) =>
            const Divider(color: AppColors.divider, height: 28),
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
      children: const [
        CircleAvatar(radius: 14),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(widthFactor: .5, height: 12),
              SizedBox(height: 6),
              SkeletonLine(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

String? _currentUserAvatar(BuildContext context) {
  final s = context.read<AuthBloc>().state;
  if (s is AuthAuthenticated) {
    // Adjust the property name if your user model differs
    //return s.user.avatarUrl ?? s.user.avatar_url;
  }
  return null;
}

class _CommentTile extends StatefulWidget {
  final Comment c;
  const _CommentTile({required this.c});
  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _expanded = true; // open by default like your screenshot

  void _openReplySheet(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const CircleAvatar(
                  backgroundImage: NetworkImage(
                    'https://i.pravatar.cc/150?img=5',
                  ),
                  radius: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Write a reply…',
                      filled: true,
                      fillColor: Color(0xFF131B34),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: () {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    context.read<PostCubit>().addReply(widget.c.id, text);
                    Navigator.pop(context);
                  },
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
        // original row ...
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(backgroundImage: NetworkImage(c.user.avatarUrl)),
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
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      RolePill(
                        text: c.user.roleLabel,
                        color: Color(
                          int.parse(
                                c.user.roleColor.substring(1, 7),
                                radix: 16,
                              ) +
                              0xFF000000,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(c.text, style: AppTextStyles.body),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        timeAgo(DateTime.now().difference(c.createdAt)),
                        style: AppTextStyles.small,
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () =>
                            context.read<PostCubit>().toggleCommentLike(c.id),
                        child: const Icon(Icons.favorite_border, size: 16),
                      ),
                      const SizedBox(width: 4),
                      Text('${c.likes}', style: AppTextStyles.small),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _openReplySheet(context),
                        child: Text(
                          'Reply',
                          style: AppTextStyles.small.copyWith(
                            color: AppColors.hashtag,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // View replies (n)
                  if (c.replies.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        _expanded
                            ? 'Hide replies (${c.replies.length})'
                            : 'View replies (${c.replies.length})',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (_expanded && c.replies.isNotEmpty) ...[
          const SizedBox(height: 10),
          // nested replies
          Column(
            children: c.replies.map((r) {
              return Padding(
                padding: const EdgeInsets.only(left: 46, bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: NetworkImage(r.user.avatarUrl),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.user.name,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(r.text, style: AppTextStyles.body),
                          const SizedBox(height: 6),
                          Text(
                            timeAgo(DateTime.now().difference(r.createdAt)),
                            style: AppTextStyles.small,
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.navy,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=5'),
              radius: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: 'Write a comment...',
                  filled: true,
                  fillColor: Color(0xFF131B34),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () {
                if (_ctrl.text.trim().isEmpty) return;
                widget.onSubmit(_ctrl.text.trim());
                _ctrl.clear();
              },
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
