// lib/features/post_view/presentation/pages/post_view_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/core/widgets/sign_in_prompt.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/post_view/presentation/widgets/skeleton_line_plus.dart';
import 'package:moonlight/features/post_view/presentation/widgets/user_helper.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../core/routing/route_names.dart'; // <-- ADDED
import '../../../../core/services/share_service.dart'; // <-- ADDED
import '../../domain/entities/post.dart';
import '../../domain/entities/comment.dart';
import '../cubit/post_cubit.dart';
import '../cubit/post_actions.dart';
import '../widgets/chips.dart';
import '../widgets/sheets.dart';

class PostViewScreen extends StatefulWidget {
  final String postId;
  final bool isOwner;
  const PostViewScreen({super.key, required this.postId, this.isOwner = false});

  @override
  State<PostViewScreen> createState() => _PostViewScreenState();
}

class _PostViewScreenState extends State<PostViewScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyingToCommentId;
  String? _replyingToUserName;
  String? _editingCommentId;
  String? _editingCommentText;
  String? _currentUserId;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user.id;
    }
  }

  void _startReply(String commentId, String userName) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserName = userName;
      _editingCommentId = null;
      _editingCommentText = null;
      _commentController.text = '@$userName ';
      _commentFocusNode.requestFocus();
    });
  }

  void _startEditComment(String commentId, String currentText) {
    setState(() {
      _editingCommentId = commentId;
      _editingCommentText = currentText;
      _replyingToCommentId = null;
      _replyingToUserName = null;
      _commentController.text = currentText;
      _commentFocusNode.requestFocus();
    });
  }

  void _cancelAction() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
      _editingCommentId = null;
      _editingCommentText = null;
      _commentController.clear();
      _commentFocusNode.unfocus();
    });
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final cubit = context.read<PostCubit>();

    if (_editingCommentId != null) {
      cubit.editComment(_editingCommentId!, text);
    } else if (_replyingToCommentId != null) {
      cubit.addReply(_replyingToCommentId!, text);
    } else {
      cubit.addComment(text);
    }

    _cancelAction();
  }

  void _confirmDeleteComment(String commentId) {
    final postCubit = context.read<PostCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogContext) => BlocProvider.value(
        value: postCubit,
        child: _ConfirmDeleteSheet(
          title: 'Delete Comment?',
          message: 'This comment will be permanently deleted.',
          confirmText: 'Delete',
          onConfirm: () {
            postCubit.deleteComment(commentId);
            Navigator.pop(dialogContext);
          },
          isBusy: postCubit.state.deletingCommentIds.contains(commentId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PostCubit, PostState>(
      listenWhen: (prev, curr) => prev.lastAction != curr.lastAction,
      listener: (context, state) {
        final action = state.lastAction;
        if (action == null) return;

        SnackBar makeSnack(IconData icon, Color bg, String msg) => SnackBar(
          backgroundColor: bg,
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                msg,
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        );

        if (action is PostDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            makeSnack(Icons.check_circle, Colors.green, 'Post deleted'),
          );
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        } else if (action is PostEdited) {
          ScaffoldMessenger.of(context).showSnackBar(
            makeSnack(Icons.check_circle, Colors.green, 'Caption updated'),
          );
        } else if (action is CommentAdded) {
          ScaffoldMessenger.of(context).showSnackBar(
            makeSnack(Icons.check_circle, Colors.green, 'Comment posted'),
          );
        } else if (action is CommentEdited) {
          ScaffoldMessenger.of(context).showSnackBar(
            makeSnack(Icons.check_circle, Colors.green, 'Comment edited'),
          );
        } else if (action is CommentDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            makeSnack(Icons.check_circle, Colors.green, 'Comment deleted'),
          );
        } else if (action is ReplyAdded) {
          ScaffoldMessenger.of(context).showSnackBar(
            makeSnack(Icons.check_circle, Colors.green, 'Reply posted'),
          );
        } else if (action is ReplyEdited) {
          ScaffoldMessenger.of(context).showSnackBar(
            makeSnack(Icons.check_circle, Colors.green, 'Reply edited'),
          );
        } else if (action is ReplyDeleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            makeSnack(Icons.check_circle, Colors.green, 'Reply deleted'),
          );
        } else if (action is ActionFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            makeSnack(Icons.error_outline, Colors.red, action.message),
          );
        }

        context.read<PostCubit>().consumeAction();
      },
      child: BlocBuilder<PostCubit, PostState>(
        builder: (context, state) {
          try {
            return WillPopScope(
              onWillPop: () async {
                final post = context.read<PostCubit>().state.post;
                Navigator.pop(context, post);
                return false;
              },
              child: _buildBody(context, context.read<PostCubit>()),
            );
          } catch (e) {
            debugPrint('❌ PostCubit access error: $e');
            return _buildErrorScreen(e);
          }
        },
      ),
    );
  }

  Widget _buildErrorScreen(dynamic error) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading post',
              style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: AppTextStyles.body.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<PostCubit>().load();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFatalPostScreen({
    required String title,
    required String subtitle,
  }) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 88,
                width: 88,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Feed'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PostCubit cubit) {
    final post = cubit.state.post;
    if (cubit.state.loading) return const _PostViewShimmer();
    if (post == null) {
      return _buildFatalPostScreen(
        title: 'Post not available',
        subtitle:
            'This post may have been removed or is temporarily unavailable.',
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Color(0xFF0B1E6B), Color(0xFF031049)],
                      ),
                    ),
                  ),
                ),
                CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      pinned: false,
                      floating: true,
                      leading: IconButton(
                        onPressed: () {
                          final p = context.read<PostCubit>().state.post;
                          Navigator.pop(context, p);
                        },
                        icon: const Icon(Icons.arrow_back_ios_new),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Hero(
                        tag: 'post_${post.id}',
                        child: _PostMedia(post: post),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        color: AppColors.surface,
                        child: _Meta(
                          post: post,
                          onStartReply: _startReply,
                          onEditComment: _startEditComment,
                          onDeleteComment: _confirmDeleteComment,
                          cubit: cubit,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _CommentInputBar(
            controller: _commentController,
            focusNode: _commentFocusNode,
            replyingToCommentId: _replyingToCommentId,
            replyingToUserName: _replyingToUserName,
            editingCommentId: _editingCommentId,
            onCancel: _cancelAction,
            onSubmit: _submitComment,
          ),
        ],
      ),
    );
  }
}

class _PostMedia extends StatefulWidget {
  final Post post;
  const _PostMedia({required this.post});

  @override
  State<_PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<_PostMedia> {
  VideoPlayerController? _vc;
  bool _isVideo = false;
  bool _showGlyph = true;

  bool get _isInitialized => _vc?.value.isInitialized == true;

  @override
  void initState() {
    super.initState();
    _isVideo = _detectVideo(widget.post);
    _initVideoIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _PostMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.mediaUrl != widget.post.mediaUrl) {
      _disposeVc();
      _isVideo = _detectVideo(widget.post);
      _initVideoIfNeeded();
    }
  }

  @override
  void dispose() {
    _disposeVc();
    super.dispose();
  }

  void _disposeVc() {
    _vc?.dispose();
    _vc = null;
  }

  bool _detectVideo(Post p) {
    final t = (p.mediaType ?? '').toLowerCase();
    if (t.startsWith('video/')) return true;
    final u = (p.mediaUrl).toLowerCase();
    return u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.mkv') ||
        u.endsWith('.webm');
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  void _initVideoIfNeeded() {
    if (!_isVideo) return;
    if (!_isValidUrl(widget.post.mediaUrl)) return;
    try {
      final uri = Uri.parse(widget.post.mediaUrl);
      _vc = VideoPlayerController.networkUrl(uri)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _vc?.play();
          _vc?.setLooping(true);
          _flashGlyph();
        });
    } catch (_) {
      // Invalid URL string; ignore and render placeholder
    }
  }

  String get _previewUrl {
    final thumb = widget.post.thumbUrl;
    if (_isValidUrl(thumb)) return thumb!;
    return _isValidUrl(widget.post.mediaUrl) ? widget.post.mediaUrl : '';
  }

  void _togglePlay() {
    if (!_isVideo || !_isInitialized) return;
    final playing = _vc!.value.isPlaying;
    if (playing) {
      _vc!.pause();
    } else {
      _vc!.play();
    }
    _flashGlyph();
    setState(() {});
  }

  Future<void> _flashGlyph() async {
    setState(() => _showGlyph = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _showGlyph = false);
  }

  @override
  Widget build(BuildContext context) {
    const defaultAspect = 375 / 380;

    if (!_isVideo) {
      if (!_isValidUrl(widget.post.mediaUrl)) {
        return const AspectRatio(
          aspectRatio: defaultAspect,
          child: _MediaPlaceholder(),
        );
      }
      return AspectRatio(
        aspectRatio: defaultAspect,
        child: CachedNetworkImage(
          imageUrl: widget.post.mediaUrl,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (_, __) => Container(color: Colors.white10),
          errorWidget: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
    }

    final ar = _isInitialized
        ? (_vc!.value.aspectRatio > 0 ? _vc!.value.aspectRatio : defaultAspect)
        : defaultAspect;

    return AspectRatio(
      aspectRatio: ar,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_isInitialized)
            _isValidUrl(_previewUrl)
                ? CachedNetworkImage(
                    imageUrl: _previewUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.white10),
                    errorWidget: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  )
                : const _MediaPlaceholder(),
          if (_isInitialized) VideoPlayer(_vc!),
          Material(
            color: Colors.transparent,
            child: InkWell(onTap: _togglePlay),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
          ),
          if (_showGlyph && _isInitialized)
            Center(
              child: Icon(
                _vc!.value.isPlaying
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_fill_rounded,
                size: 72,
                color: Colors.white,
              ),
            ),
          if (_isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                _vc!,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.photo, color: Colors.white38, size: 40),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final Post post;
  final Function(String, String) onStartReply;
  final Function(String, String) onEditComment;
  final Function(String) onDeleteComment;
  final PostCubit cubit;

  const _Meta({
    required this.post,
    required this.onStartReply,
    required this.onEditComment,
    required this.onDeleteComment,
    required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserService = Provider.of<CurrentUserService>(context);
    final isPostOwner = UserHelper.isPostOwner(context, post);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SafeCircleAvatar(
                imageUrl: post.author.avatarUrl,
                radius: 16,
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.profileView,
                  arguments: {'userUuid': post.author.id},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            RouteNames.profileView,
                            arguments: {'userUuid': post.author.id},
                          ),
                          child: Text(
                            post.author.name,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(post.author.countryFlagEmoji),
                      ],
                    ),
                    const SizedBox(height: 6),
                    RolePill(
                      text: post.author.roleLabel,
                      color: const Color(0xFF4C8DFF),
                    ),
                  ],
                ),
              ),
              Text(
                timeAgo(DateTime.now().difference(post.createdAt)),
                style: AppTextStyles.small,
              ),
              const SizedBox(width: 6),
              _PostMenuButton(isOwner: isPostOwner, post: post),
            ],
          ),
          const SizedBox(height: 12),
          Text(post.caption, style: AppTextStyles.body),
          const SizedBox(height: 8),
          Wrap(children: post.tags.map((t) => TagChip(text: t)).toList()),
          const SizedBox(height: 14),
          Row(
            children: [
              _IconStat(
                icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                value: post.likes.toString(),
                onTap: () => cubit.toggleLike(),
                active: post
                    .isLiked, // stays red if liked (persisted by LikeMemory)
              ),
              const SizedBox(width: 18),
              _IconStat(
                icon: Icons.mode_comment_outlined,
                value: post.commentsCount.toString(),
                onTap: () {},
              ),
              const SizedBox(width: 18),
              _IconStat(
                icon: Icons.share_outlined,
                value: "",
                onTap: () async {
                  await ShareService.sharePost(post);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Comments',
                style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
              ),
              if (post.commentsCount > 3)
                Text(
                  '${post.commentsCount} comments',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCommentsList(context),
          if (cubit.state.commentsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentsList(BuildContext context) {
    final comments = cubit.state.comments;

    if (comments.isEmpty) {
      return _buildEmptyComments();
    }

    return Column(
      children: comments
          .map(
            (comment) => _CommentTile(
              comment: comment,
              onStartReply: onStartReply,
              onEditComment: onEditComment,
              onDeleteComment: onDeleteComment,
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmptyComments() {
    // Ultra-modern empty-state card
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16214B), Color(0xFF0E1631)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.06)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mode_comment_outlined,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No comments yet',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Be the first to comment',
                  style: AppTextStyles.small.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  final Comment comment;
  final Function(String, String) onStartReply;
  final Function(String, String) onEditComment;
  final Function(String) onDeleteComment;

  const _CommentTile({
    required this.comment,
    required this.onStartReply,
    required this.onEditComment,
    required this.onDeleteComment,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _expanded = true;

  bool get _isCurrentUserComment {
    return UserHelper.isCommentOwner(context, widget.comment);
  }

  void _showCommentMenu() {
    final postCubit = context.read<PostCubit>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (menuContext) => BlocProvider.value(
        value: postCubit,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuOption(
                  icon: Icons.reply,
                  title: 'Reply',
                  onTap: () {
                    Navigator.pop(menuContext);
                    widget.onStartReply(
                      widget.comment.id,
                      widget.comment.user.name,
                    );
                  },
                ),
                if (_isCurrentUserComment) ...[
                  const Divider(color: AppColors.divider),
                  _MenuOption(
                    icon: Icons.edit,
                    title: 'Edit Comment',
                    onTap: () {
                      Navigator.pop(menuContext);
                      widget.onEditComment(
                        widget.comment.id,
                        widget.comment.text,
                      );
                    },
                  ),
                  _MenuOption(
                    icon: Icons.delete,
                    title: 'Delete Comment',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(menuContext);
                      widget.onDeleteComment(
                        widget.comment.id,
                      ); // route to confirm
                    },
                  ),
                ],
                const Divider(color: AppColors.divider),
                _MenuOption(
                  icon: Icons.flag,
                  title: 'Report Comment',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(menuContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Comment reported')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final deleting = context.select<PostCubit, bool>(
      (pc) => pc.state.deletingCommentIds.contains(c.id),
    );

    return Opacity(
      opacity: deleting ? 0.5 : 1,
      child: AbsorbPointer(
        absorbing: deleting,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeCircleAvatar(
                  imageUrl: c.user.avatarUrl,
                  radius: 16,
                  onTap: () => Navigator.pushNamed(
                    context,
                    RouteNames.profileView,
                    arguments: {'userUuid': c.user.id},
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
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                context,
                                RouteNames.profileView,
                                arguments: {'userUuid': c.user.id},
                              ),
                              child: Text(
                                c.user.name,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
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
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.more_horiz, size: 16),
                            onPressed: _showCommentMenu,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(c.text, style: AppTextStyles.body),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            timeAgo(DateTime.now().difference(c.createdAt)),
                            style: AppTextStyles.small.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => context
                                .read<PostCubit>()
                                .toggleCommentLike(c.id),
                            child: const Icon(
                              Icons.favorite_border,
                              size: 16,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${c.likes}',
                            style: AppTextStyles.small.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => widget.onStartReply(c.id, c.user.name),
                            child: Text(
                              'Reply',
                              style: AppTextStyles.small.copyWith(
                                color: AppColors.hashtag,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                    Container(width: 24, height: 1, color: AppColors.divider),
                    const SizedBox(width: 12),
                    Text(
                      _expanded
                          ? 'Hide ${c.replies.length} ${c.replies.length == 1 ? 'reply' : 'replies'}'
                          : 'View ${c.replies.length} ${c.replies.length == 1 ? 'reply' : 'replies'}',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.hashtag,
                      ),
                    ),
                  ],
                ),
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                ...c.replies.map(
                  (reply) => Padding(
                    padding: const EdgeInsets.only(left: 28, bottom: 16),
                    child: _ReplyTile(
                      reply: reply,
                      onEditComment: widget.onEditComment,
                      onDeleteComment: widget.onDeleteComment,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  final Comment reply;
  final Function(String, String) onEditComment;
  final Function(String) onDeleteComment;

  const _ReplyTile({
    required this.reply,
    required this.onEditComment,
    required this.onDeleteComment,
  });

  bool _isCurrentUserReply(BuildContext context) {
    return UserHelper.isCommentOwner(context, reply);
  }

  void _showReplyMenu(BuildContext context) {
    final postCubit = context.read<PostCubit>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (menuContext) => BlocProvider.value(
        value: postCubit,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isCurrentUserReply(context)) ...[
                  _MenuOption(
                    icon: Icons.edit,
                    title: 'Edit Reply',
                    onTap: () {
                      Navigator.pop(menuContext);
                      onEditComment(reply.id, reply.text);
                    },
                  ),
                  _MenuOption(
                    icon: Icons.delete,
                    title: 'Delete Reply',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(menuContext);
                      onDeleteComment(reply.id); // route to confirm
                    },
                  ),
                  const Divider(color: AppColors.divider),
                ],
                _MenuOption(
                  icon: Icons.flag,
                  title: 'Report Reply',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(menuContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reply reported')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deleting = context.select<PostCubit, bool>(
      (pc) => pc.state.deletingCommentIds.contains(reply.id),
    );

    return Opacity(
      opacity: deleting ? 0.5 : 1,
      child: AbsorbPointer(
        absorbing: deleting,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeCircleAvatar(
              imageUrl: reply.user.avatarUrl,
              radius: 12,
              onTap: () => Navigator.pushNamed(
                context,
                RouteNames.profileView,
                arguments: {'userUuid': reply.user.id},
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
                        child: GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            RouteNames.profileView,
                            arguments: {'userUuid': reply.user.id},
                          ),
                          child: Text(
                            reply.user.name,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz, size: 14),
                        onPressed: () => _showReplyMenu(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reply.text,
                    style: AppTextStyles.body.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        timeAgo(DateTime.now().difference(reply.createdAt)),
                        style: AppTextStyles.small.copyWith(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => context
                            .read<PostCubit>()
                            .toggleCommentLike(reply.id),
                        child: const Icon(
                          Icons.favorite_border,
                          size: 14,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${reply.likes}',
                        style: AppTextStyles.small.copyWith(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.white),
      title: Text(
        title,
        style: AppTextStyles.body.copyWith(
          color: isDestructive ? Colors.red : Colors.white,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _PostMenuButton extends StatelessWidget {
  final bool isOwner;
  final Post post;

  const _PostMenuButton({required this.isOwner, required this.post});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        if (isOwner) {
          await _showOwnerMenu(context);
        } else {
          await _showViewerMenu(context);
        }
      },
      icon: const Icon(Icons.more_horiz),
    );
  }

  Future<void> _showOwnerMenu(BuildContext context) async {
    final postCubit = context.read<PostCubit>();
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: postCubit,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuOption(
                  icon: Icons.edit,
                  title: 'Edit Post',
                  onTap: () {
                    Navigator.pop(ctx);
                    _editPost(context);
                  },
                ),
                _MenuOption(
                  icon: Icons.delete,
                  title: 'Delete Post',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _deletePost(context);
                  },
                ),
                const Divider(color: AppColors.divider),
                _MenuOption(
                  icon: Icons.share,
                  title: 'Share',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ShareService.sharePost(post);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showViewerMenu(BuildContext context) async {
    final postCubit = context.read<PostCubit>();
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: postCubit,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuOption(
                  icon: Icons.flag,
                  title: 'Report Post',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _reportPost(context);
                  },
                ),
                const Divider(color: AppColors.divider),
                _MenuOption(
                  icon: Icons.share,
                  title: 'Share',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ShareService.sharePost(post);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editPost(BuildContext context) {
    final postCubit = context.read<PostCubit>();
    final textController = TextEditingController(text: post.caption);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogContext) => BlocProvider.value(
        value: postCubit,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Caption',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A233F),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: textController,
                    maxLines: 4,
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'What\'s on your mind?',
                      hintStyle: AppTextStyles.body.copyWith(
                        color: Colors.white54,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Cancel', style: AppTextStyles.body),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final newCaption = textController.text.trim();
                          if (newCaption.isNotEmpty &&
                              newCaption != post.caption) {
                            try {
                              await postCubit.editCaption(newCaption);
                              Navigator.pop(dialogContext);
                            } catch (_) {
                              Navigator.pop(dialogContext);
                            }
                          } else {
                            Navigator.pop(dialogContext);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Save', style: AppTextStyles.body),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deletePost(BuildContext context) {
    final postCubit = context.read<PostCubit>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogContext) => BlocProvider.value(
        value: postCubit,
        child: _ConfirmDeleteSheet(
          title: 'Delete Post?',
          message:
              'This action cannot be undone. The post will be permanently deleted.',
          confirmText: 'Delete',
          isBusy: postCubit.state.deletingPost,
          onConfirm: () {
            postCubit.deletePost();
            Navigator.pop(dialogContext);
          },
        ),
      ),
    );
  }

  void _reportPost(BuildContext context) async {
    final postCubit = context.read<PostCubit>();
    final reason = await pickReason(context);
    if (reason == null) return;

    try {
      await postCubit.repo.report(postCubit.postId, reason);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks for reporting. We\'ll review it.'),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not report right now.')),
      );
    }
  }
}

class _ConfirmDeleteSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final bool isBusy;
  final VoidCallback onConfirm;

  const _ConfirmDeleteSheet({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.onConfirm,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete, color: Colors.red, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Cancel', style: AppTextStyles.body),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isBusy ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isBusy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(confirmText, style: AppTextStyles.body),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyingToCommentId;
  final String? replyingToUserName;
  final String? editingCommentId;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _CommentInputBar({
    required this.controller,
    required this.focusNode,
    this.replyingToCommentId,
    this.replyingToUserName,
    this.editingCommentId,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserService = Provider.of<CurrentUserService>(context);
    final hasAction = replyingToCommentId != null || editingCommentId != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.navyDark,
        border: Border(
          top: BorderSide(color: AppColors.divider.withOpacity(0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasAction) ...[
            Row(
              children: [
                Text(
                  editingCommentId != null
                      ? 'Editing comment'
                      : 'Replying to ${replyingToUserName ?? ''}',
                  style: AppTextStyles.small.copyWith(color: AppColors.hashtag),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onCancel,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (!currentUserService.isLoggedIn)
            const SignInPrompt(onDismiss: null)
          else
            _buildCommentInput(currentUserService, hasAction),
        ],
      ),
    );
  }

  Widget _buildCommentInput(
    CurrentUserService currentUserService,
    bool hasAction,
  ) {
    return Row(
      children: [
        SafeCircleAvatar(
          imageUrl: currentUserService.getCurrentAvatar(),
          radius: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131B34),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hasAction
                    ? (editingCommentId != null
                          ? 'Edit your comment...'
                          : 'Write a reply...')
                    : 'Write a comment...',
                hintStyle: AppTextStyles.body.copyWith(color: Colors.white54),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onSubmit,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.send_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final bool active;
  const _IconStat({
    required this.icon,
    required this.value,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: active ? AppColors.like : AppColors.onSurface),
          const SizedBox(width: 8),
          Text('$value', style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _PostViewShimmer extends StatelessWidget {
  const _PostViewShimmer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Skeletonizer(
        enabled: true,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Color(0xFF0B1E6B), Color(0xFF031049)],
                  ),
                ),
              ),
            ),
            CustomScrollView(
              slivers: [
                const SliverAppBar(
                  backgroundColor: Colors.transparent,
                  pinned: false,
                  floating: true,
                  leading: Icon(Icons.arrow_back_ios_new),
                ),
                SliverToBoxAdapter(
                  child: AspectRatio(
                    aspectRatio: 375 / 380,
                    child: Container(color: Colors.white10),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.surface,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(radius: 16),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SkeletonLine(widthFactor: .5, height: 12),
                                    SizedBox(height: 6),
                                    SkeletonPill(width: 80, height: 18),
                                  ],
                                ),
                              ),
                              SkeletonLine(width: 40, height: 12),
                              SizedBox(width: 6),
                              Icon(Icons.more_horiz),
                            ],
                          ),
                          SizedBox(height: 12),
                          SkeletonLine(height: 12),
                          SizedBox(height: 6),
                          SkeletonLine(widthFactor: .8, height: 12),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SkeletonPill(width: 64, height: 22),
                              SkeletonPill(width: 56, height: 22),
                              SkeletonPill(width: 72, height: 22),
                            ],
                          ),
                          SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(Icons.favorite_border),
                              SizedBox(width: 18),
                              Icon(Icons.mode_comment_outlined),
                              SizedBox(width: 18),
                              Icon(Icons.share_outlined),
                            ],
                          ),
                          SizedBox(height: 16),
                          Divider(color: AppColors.divider),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SkeletonLine(width: 100, height: 16),
                              SkeletonLine(width: 120, height: 16),
                            ],
                          ),
                          SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SafeCircleAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final VoidCallback? onTap; // <-- ADDED

  const SafeCircleAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    this.onTap, // <-- ADDED
  });

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  @override
  Widget build(BuildContext context) {
    final valid = _isValidUrl(imageUrl);

    final core = valid
        ? ClipOval(
            child: SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.primary.withOpacity(0.15),
                  child: Icon(
                    Icons.person,
                    size: radius,
                    color: Colors.white54,
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.primary.withOpacity(0.25),
                  child: Icon(
                    Icons.person,
                    size: radius,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary.withOpacity(0.25),
            child: Icon(Icons.person, size: radius, color: Colors.white70),
          );

    if (onTap == null) return core;
    return GestureDetector(onTap: onTap, child: core);
  }
}
