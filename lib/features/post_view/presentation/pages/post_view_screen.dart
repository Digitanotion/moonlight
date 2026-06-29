// lib/features/post_view/presentation/pages/post_view_screen.dart
//
// VISUAL REFINEMENT — same design language as the feed redesign:
//   • Flat near-black background instead of the navy gradient
//   • Hairline borders instead of heavy shadows
//   • Accent-tinted role pills with letter-spacing
//   • Real animated shimmer loading state (ShimmerScope/ShimmerBone)
//     instead of Skeletonizer (which rendered blank)
//
// NO functional changes: every callback, cubit method, route, and menu
// action is identical to the original. Only colors, spacing, borders,
// and the loading skeleton changed.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/core/utils/time_ago.dart';
import 'package:moonlight/core/widgets/sign_in_prompt.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/post_view/presentation/widgets/skeleton_line_plus.dart';
import 'package:moonlight/features/post_view/presentation/widgets/user_helper.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/routing/route_names.dart';
import '../../../../core/services/share_service.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/comment.dart';
import '../cubit/post_cubit.dart';
import '../cubit/post_actions.dart';
import '../widgets/chips.dart';
import '../widgets/sheets.dart';

// ── Design tokens (shared with feed redesign) ──────────────────────────────
class _C {
  static const bg = Color(0xFF05060F);
  static const surface = Color(0xFF0E1024);
  static const border = Color(0xFF1A1D3D);
  static const accent = Color(0xFFFF6A00);
  static const textSecondary = Color(0xFF8B8FB8);
}

const _kLikedColor = _C.accent;

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
      backgroundColor: _C.surface,
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
          if (Navigator.canPop(context)) Navigator.pop(context);
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
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.surface,
                  border: Border.all(color: _C.border),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Error loading post',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: _C.textSecondary, fontSize: 13.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              _PrimaryButton(
                label: 'Retry',
                onTap: () => context.read<PostCubit>().load(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFatalPostScreen({
    required String title,
    required String subtitle,
  }) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.surface,
                  border: Border.all(color: _C.border),
                ),
                child: const Icon(
                  Icons.image_not_supported_rounded,
                  color: Colors.white38,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: _C.textSecondary, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: _PrimaryButton(
                  label: 'Back to Feed',
                  onTap: () => Navigator.pop(context),
                  expand: true,
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
      backgroundColor: _C.bg,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: _C.bg,
                  surfaceTintColor: Colors.transparent,
                  pinned: false,
                  floating: true,
                  elevation: 0,
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
                  child: _Meta(
                    post: post,
                    onStartReply: _startReply,
                    onEditComment: _startEditComment,
                    onDeleteComment: _confirmDeleteComment,
                    cubit: cubit,
                  ),
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

// ── Small shared button ────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool expand;
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _C.accent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
          ),
        ),
      ),
    );
    return expand ? child : IntrinsicWidth(child: child);
  }
}

// ── Post media ────────────────────────────────────────────────────────────

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
    final u = p.mediaUrl.toLowerCase();
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
    } catch (_) {}
  }

  String get _previewUrl {
    if (_isVideo) {
      final thumb = widget.post.thumbUrl;
      if (_isValidUrl(thumb)) return thumb!;
    }
    return _isValidUrl(widget.post.mediaUrl) ? widget.post.mediaUrl : '';
  }

  void _togglePlay() {
    if (!_isVideo || !_isInitialized) return;
    final playing = _vc!.value.isPlaying;
    playing ? _vc!.pause() : _vc!.play();
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
          placeholder: (_, __) => Container(color: _C.border),
          errorWidget: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white38),
          ),
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
                    placeholder: (_, __) => Container(color: _C.border),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, color: Colors.white38),
                    ),
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
              child: AnimatedOpacity(
                opacity: _showGlyph ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black45,
                  ),
                  child: Icon(
                    _vc!.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
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
                colors: VideoProgressColors(
                  playedColor: _C.accent,
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
      color: _C.border,
      child: const Center(
        child: Icon(Icons.image_rounded, color: Colors.white24, size: 36),
      ),
    );
  }
}

// ── Role pill — matches feed card's accent-tinted style ────────────────────
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
        style: TextStyle(
          color: _C.accent,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Meta section ──────────────────────────────────────────────────────────────

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
    final isPostOwner = UserHelper.isPostOwner(context, post);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              SafeCircleAvatar(
                imageUrl: post.author.avatarUrl,
                radius: 18,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(post.author.countryFlagEmoji),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _RolePillTinted(label: post.author.roleLabel),
                  ],
                ),
              ),
              Text(
                timeAgoFrom(post.createdAt),
                style: TextStyle(
                  color: _C.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              _PostMenuButton(isOwner: isPostOwner, post: post),
            ],
          ),

          const SizedBox(height: 14),
          if (post.caption.isNotEmpty)
            Text(
              post.caption,
              style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.45),
            ),
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.tags.map((t) => TagChip(text: t)).toList(),
            ),
          ],
          const SizedBox(height: 16),

          // ── Action row: like · comment · share ─────────────────────────
          Row(
            children: [
              _AnimatedLikeStat(
                isLiked: post.isLiked,
                count: post.likes,
                onTap: () => cubit.toggleLike(),
              ),
              const SizedBox(width: 20),
              _IconStat(
                icon: Icons.mode_comment_rounded,
                value: post.commentsCount.toString(),
                onTap: () {},
              ),
              const SizedBox(width: 20),
              _ShareButton(post: post),
            ],
          ),

          const SizedBox(height: 20),
          Container(height: 1, color: _C.border),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (post.commentsCount > 3)
                Text(
                  '${post.commentsCount} comments',
                  style: TextStyle(color: _C.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildCommentsList(context),
          if (cubit.state.commentsLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _C.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentsList(BuildContext context) {
    final comments = cubit.state.comments;
    if (comments.isEmpty) return _buildEmptyComments();
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: _C.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mode_comment_rounded, color: _C.accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No comments yet',
                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'Be the first to comment',
                  style: TextStyle(color: _C.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated like stat (post-view version) ───────────────────────────────────

class _AnimatedLikeStat extends StatefulWidget {
  const _AnimatedLikeStat({
    required this.isLiked,
    required this.count,
    required this.onTap,
  });
  final bool isLiked;
  final int count;
  final VoidCallback onTap;

  @override
  State<_AnimatedLikeStat> createState() => _AnimatedLikeStatState();
}

class _AnimatedLikeStatState extends State<_AnimatedLikeStat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    lowerBound: 0.7,
    upperBound: 1.0,
    value: 1.0,
  );

  Future<void> _handleTap() async {
    await _ctrl.animateTo(
      0.7,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeIn,
    );
    await _ctrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.elasticOut,
    );
    widget.onTap();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isLiked ? _kLikedColor : _C.textSecondary;
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _ctrl,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(widget.isLiked),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 7),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13.5),
              child: Text('${widget.count}'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Share button ──────────────────────────────────────────────────────────────

class _ShareButton extends StatelessWidget {
  final Post post;
  const _ShareButton({required this.post});

  void _show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Share post',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ShareOption(
                    icon: Icons.share_rounded,
                    label: 'Share via',
                    color: _C.accent,
                    onTap: () async {
                      Navigator.pop(context);
                      await ShareService.sharePost(post);
                    },
                  ),
                  _ShareOption(
                    icon: Icons.copy_rounded,
                    label: 'Copy link',
                    color: const Color(0xFF4C8DFF),
                    onTap: () {
                      Navigator.pop(context);
                      final link = 'https://moonlightstream.app/post/${post.id}';
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Link copied to clipboard'),
                          backgroundColor: _C.accent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _show(context),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.share_rounded, color: _C.textSecondary, size: 19),
          const SizedBox(width: 7),
          Text('Share', style: TextStyle(color: _C.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ── Comment tile ──────────────────────────────────────────────────────────────

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

  bool get _isCurrentUserComment =>
      UserHelper.isCommentOwner(context, widget.comment);

  void _showCommentMenu() {
    final postCubit = context.read<PostCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
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
                  icon: Icons.reply_rounded,
                  title: 'Reply',
                  onTap: () {
                    Navigator.pop(menuContext);
                    widget.onStartReply(widget.comment.id, widget.comment.user.name);
                  },
                ),
                if (_isCurrentUserComment) ...[
                  Container(height: 1, color: _C.border),
                  _MenuOption(
                    icon: Icons.edit_rounded,
                    title: 'Edit Comment',
                    onTap: () {
                      Navigator.pop(menuContext);
                      widget.onEditComment(widget.comment.id, widget.comment.text);
                    },
                  ),
                  _MenuOption(
                    icon: Icons.delete_rounded,
                    title: 'Delete Comment',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(menuContext);
                      widget.onDeleteComment(widget.comment.id);
                    },
                  ),
                ],
                Container(height: 1, color: _C.border),
                _MenuOption(
                  icon: Icons.flag_rounded,
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
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SafeCircleAvatar(
                    imageUrl: c.user.avatarUrl,
                    radius: 17,
                    onTap: () => Navigator.pushNamed(
                      context,
                      RouteNames.profileView,
                      arguments: {'userUuid': c.user.id},
                    ),
                  ),
                  const SizedBox(width: 11),
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                            if (c.user.roleLabel.isNotEmpty)
                              _RolePillTinted(label: c.user.roleLabel),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _showCommentMenu,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.more_horiz_rounded, size: 16, color: Colors.white38),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          c.text,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Text(
                              timeAgoFrom(c.createdAt),
                              style: TextStyle(color: _C.textSecondary, fontSize: 11.5),
                            ),
                            const SizedBox(width: 14),
                            _CommentLikeButton(
                              commentId: c.id,
                              isLiked: c.isLiked,
                              likes: c.likes,
                            ),
                            const SizedBox(width: 14),
                            GestureDetector(
                              onTap: () => widget.onStartReply(c.id, c.user.name),
                              child: Text(
                                'Reply',
                                style: TextStyle(
                                  color: _C.accent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
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
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      children: [
                        Container(width: 20, height: 1, color: _C.border),
                        const SizedBox(width: 10),
                        Text(
                          _expanded
                              ? 'Hide ${c.replies.length} ${c.replies.length == 1 ? 'reply' : 'replies'}'
                              : 'View ${c.replies.length} ${c.replies.length == 1 ? 'reply' : 'replies'}',
                          style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  ...c.replies.map(
                    (reply) => Padding(
                      padding: const EdgeInsets.only(left: 28, bottom: 14),
                      child: _ReplyTile(
                        reply: reply,
                        onEditComment: widget.onEditComment,
                        onDeleteComment: widget.onDeleteComment,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Comment like button (red→orange when liked, matches accent) ───────────

class _CommentLikeButton extends StatefulWidget {
  final String commentId;
  final bool isLiked;
  final int likes;

  const _CommentLikeButton({
    required this.commentId,
    required this.isLiked,
    required this.likes,
  });

  @override
  State<_CommentLikeButton> createState() => _CommentLikeButtonState();
}

class _CommentLikeButtonState extends State<_CommentLikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    lowerBound: 0.7,
    upperBound: 1.0,
    value: 1.0,
  );

  Future<void> _handleTap() async {
    await _ctrl.animateTo(0.7, duration: const Duration(milliseconds: 80), curve: Curves.easeIn);
    await _ctrl.animateTo(1.0, duration: const Duration(milliseconds: 180), curve: Curves.elasticOut);
    if (mounted) {
      context.read<PostCubit>().toggleCommentLike(widget.commentId);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isLiked ? _kLikedColor : _C.textSecondary;
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _ctrl,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(widget.isLiked),
                size: 14,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text('${widget.likes}', style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Reply tile ────────────────────────────────────────────────────────────────

class _ReplyTile extends StatelessWidget {
  final Comment reply;
  final Function(String, String) onEditComment;
  final Function(String) onDeleteComment;

  const _ReplyTile({
    required this.reply,
    required this.onEditComment,
    required this.onDeleteComment,
  });

  bool _isCurrentUserReply(BuildContext context) =>
      UserHelper.isCommentOwner(context, reply);

  void _showReplyMenu(BuildContext context) {
    final postCubit = context.read<PostCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
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
                    icon: Icons.edit_rounded,
                    title: 'Edit Reply',
                    onTap: () {
                      Navigator.pop(menuContext);
                      onEditComment(reply.id, reply.text);
                    },
                  ),
                  _MenuOption(
                    icon: Icons.delete_rounded,
                    title: 'Delete Reply',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(menuContext);
                      onDeleteComment(reply.id);
                    },
                  ),
                  Container(height: 1, color: _C.border),
                ],
                _MenuOption(
                  icon: Icons.flag_rounded,
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
              radius: 13,
              onTap: () => Navigator.pushNamed(
                context,
                RouteNames.profileView,
                arguments: {'userUuid': reply.user.id},
              ),
            ),
            const SizedBox(width: 11),
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showReplyMenu(context),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.more_horiz_rounded, size: 14, color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(reply.text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(timeAgoFrom(reply.createdAt), style: TextStyle(color: _C.textSecondary, fontSize: 11)),
                      const SizedBox(width: 12),
                      _CommentLikeButton(commentId: reply.id, isLiked: reply.isLiked, likes: reply.likes),
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

// ── Shared menu option ────────────────────────────────────────────────────────

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
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ── Post menu button ──────────────────────────────────────────────────────────

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
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70),
    );
  }

  Future<void> _showOwnerMenu(BuildContext context) async {
    final postCubit = context.read<PostCubit>();
    await showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
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
                  icon: Icons.edit_rounded,
                  title: 'Edit Post',
                  onTap: () {
                    Navigator.pop(ctx);
                    _editPost(context);
                  },
                ),
                _MenuOption(
                  icon: Icons.delete_rounded,
                  title: 'Delete Post',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _deletePost(context);
                  },
                ),
                Container(height: 1, color: _C.border),
                _MenuOption(
                  icon: Icons.share_rounded,
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
      backgroundColor: _C.surface,
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
                  icon: Icons.flag_rounded,
                  title: 'Report Post',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    _reportPost(context);
                  },
                ),
                Container(height: 1, color: _C.border),
                _MenuOption(
                  icon: Icons.share_rounded,
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
      backgroundColor: _C.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogContext) => BlocProvider.value(
        value: postCubit,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Caption',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: _C.bg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _C.border),
                  ),
                  child: TextField(
                    controller: textController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(color: _C.textSecondary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: _C.border),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final newCaption = textController.text.trim();
                          if (newCaption.isNotEmpty && newCaption != post.caption) {
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
                          backgroundColor: _C.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
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
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogContext) => BlocProvider.value(
        value: postCubit,
        child: _ConfirmDeleteSheet(
          title: 'Delete Post?',
          message: 'This action cannot be undone. The post will be permanently deleted.',
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
        const SnackBar(content: Text("Thanks for reporting. We'll review it.")),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not report right now.')),
      );
    }
  }
}

// ── Confirm delete sheet ──────────────────────────────────────────────────────

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
              color: Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: _C.textSecondary, fontSize: 13.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: _C.border),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isBusy ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  child: isBusy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Comment input bar ─────────────────────────────────────────────────────────

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
    final currentUserService = GetIt.I<CurrentUserService>();
    final hasAction = replyingToCommentId != null || editingCommentId != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasAction) ...[
            Row(
              children: [
                Text(
                  editingCommentId != null ? 'Editing comment' : 'Replying to ${replyingToUserName ?? ''}',
                  style: TextStyle(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onCancel,
                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
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

  Widget _buildCommentInput(CurrentUserService currentUserService, bool hasAction) {
    return Row(
      children: [
        SafeCircleAvatar(imageUrl: currentUserService.getCurrentAvatar(), radius: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.border),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: hasAction
                    ? (editingCommentId != null ? 'Edit your comment...' : 'Write a reply...')
                    : 'Write a comment...',
                hintStyle: TextStyle(color: _C.textSecondary, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onSubmit,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _C.accent, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ── Icon stat (non-like) ──────────────────────────────────────────────────────

class _IconStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  const _IconStat({required this.icon, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _C.textSecondary, size: 19),
          const SizedBox(width: 7),
          Text(value, style: TextStyle(color: _C.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Shimmer loading state ─────────────────────────────────────────────────
// Replaces the previous Skeletonizer-based shimmer (which rendered blank
// because the wrapped widgets had no real content) with the ShimmerScope/
// ShimmerBone system — real animated diagonal sweep, TikTok/FB-style.

class _PostViewShimmer extends StatelessWidget {
  const _PostViewShimmer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: ShimmerScope(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: _C.bg,
              pinned: false,
              floating: true,
              elevation: 0,
              leading: const Icon(Icons.arrow_back_ios_new, color: Colors.white54),
            ),
            SliverToBoxAdapter(
              child: AspectRatio(
                aspectRatio: 375 / 380,
                child: ShimmerBlock(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const ShimmerCircle(radius: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              ShimmerBone(height: 13, width: 130),
                              SizedBox(height: 7),
                              ShimmerBone(height: 16, width: 70, borderRadius: BorderRadius.all(Radius.circular(20))),
                            ],
                          ),
                        ),
                        const ShimmerBone(height: 10, width: 40),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const ShimmerBone(height: 13, widthFactor: 1),
                    const SizedBox(height: 7),
                    const ShimmerBone(height: 13, widthFactor: 0.7),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        ShimmerBone(width: 60, height: 22, borderRadius: BorderRadius.all(Radius.circular(20))),
                        SizedBox(width: 8),
                        ShimmerBone(width: 52, height: 22, borderRadius: BorderRadius.all(Radius.circular(20))),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        ShimmerBone(width: 44, height: 18),
                        SizedBox(width: 20),
                        ShimmerBone(width: 44, height: 18),
                        SizedBox(width: 20),
                        ShimmerBone(width: 44, height: 18),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(height: 1, color: _C.border),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        ShimmerBone(width: 90, height: 15),
                        ShimmerBone(width: 70, height: 12),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ...List.generate(3, (i) => const Padding(
                          padding: EdgeInsets.only(bottom: 18),
                          child: _CommentRowShimmer(),
                        )),
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

class _CommentRowShimmer extends StatelessWidget {
  const _CommentRowShimmer();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShimmerCircle(radius: 17),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ShimmerBone(height: 12, width: 100),
              SizedBox(height: 7),
              ShimmerBone(height: 12, widthFactor: 1),
              SizedBox(height: 5),
              ShimmerBone(height: 12, widthFactor: 0.5),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Safe circle avatar ────────────────────────────────────────────────────────

class SafeCircleAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final VoidCallback? onTap;

  const SafeCircleAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    this.onTap,
  });

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  @override
  Widget build(BuildContext context) {
    final valid = _isValidUrl(imageUrl);

    final core = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _C.border, width: 1.5),
      ),
      child: valid
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: _C.accent.withOpacity(0.12),
                  child: Icon(Icons.person_rounded, size: radius, color: Colors.white54),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: _C.accent.withOpacity(0.16),
                  child: Icon(Icons.person_rounded, size: radius, color: Colors.white70),
                ),
              ),
            )
          : ClipOval(
              child: Container(
                color: _C.accent.withOpacity(0.16),
                child: Icon(Icons.person_rounded, size: radius, color: Colors.white70),
              ),
            ),
    );

    if (onTap == null) return core;
    return GestureDetector(onTap: onTap, child: core);
  }
}