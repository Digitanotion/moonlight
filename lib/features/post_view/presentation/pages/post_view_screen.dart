// lib/features/post_view/presentation/pages/post_view_screen.dart

import 'dart:async';
import 'package:moonlight/core/widgets/connection_toast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/share_service.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/core/utils/time_ago.dart';
import 'package:moonlight/core/widgets/sign_in_prompt.dart';
import 'package:moonlight/features/post_view/presentation/widgets/skeleton_line_plus.dart';
import 'package:moonlight/features/post_view/presentation/widgets/user_helper.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/routing/route_names.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/comment.dart';
import '../cubit/post_cubit.dart';
import '../cubit/post_actions.dart';
import '../widgets/chips.dart';
import '../widgets/sheets.dart';

class _C {
  static const bg = Color(0xFF05060F);
  static const surface = Color(0xFF0E1024);
  static const border = Color(0xFF1A1D3D);
  static const accent = Color(0xFFFF6A00);
  static const textSecondary = Color(0xFF8B8FB8);
  static const white = Colors.white;
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
  bool _isInPipMode = false;

  // Single MethodChannel — only here, NOT in _PostMediaState
  static const _pipChannel = MethodChannel('com.app.moonlightstream/pip');

  @override
  void initState() {
    super.initState();
    _pipChannel.setMethodCallHandler(_onNativePipCall);
  }

  Future<dynamic> _onNativePipCall(MethodCall call) async {
    if (call.method == 'onPipModeChanged') {
      final active = call.arguments['active'] as bool? ?? false;
      // Suppress the global network toast while PiP is showing.
      SimpleConnectionToast.pipActive.value = active;
      if (mounted) setState(() => _isInPipMode = active);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _startReply(String commentId, String userName) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserName = userName;
      _editingCommentId = null;
      _commentController.text = '@$userName ';
      _commentFocusNode.requestFocus();
    });
  }

  void _startEditComment(String commentId, String currentText) {
    setState(() {
      _editingCommentId = commentId;
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
        void showSnack(IconData icon, Color bg, String msg) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        if (action is PostDeleted) {
          showSnack(Icons.check_circle, Colors.green, 'Post deleted');
          if (Navigator.canPop(context)) Navigator.pop(context);
        } else if (action is PostEdited) {
          showSnack(Icons.check_circle, Colors.green, 'Caption updated');
        } else if (action is CommentAdded) {
          showSnack(Icons.check_circle, Colors.green, 'Comment posted');
        } else if (action is CommentEdited) {
          showSnack(Icons.check_circle, Colors.green, 'Comment edited');
        } else if (action is CommentDeleted) {
          showSnack(Icons.check_circle, Colors.green, 'Comment deleted');
        } else if (action is ReplyAdded) {
          showSnack(Icons.check_circle, Colors.green, 'Reply posted');
        } else if (action is ReplyEdited) {
          showSnack(Icons.check_circle, Colors.green, 'Reply edited');
        } else if (action is ReplyDeleted) {
          showSnack(Icons.check_circle, Colors.green, 'Reply deleted');
        } else if (action is ActionFailed) {
          showSnack(Icons.error_outline, Colors.red, action.message);
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
            return _buildErrorScreen(e);
          }
        },
      ),
    );
  }

  Widget _buildErrorScreen(dynamic error) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(context, null),
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

  PreferredSizeWidget? _buildAppBar(BuildContext context, Post? post) {
    if (_isInPipMode) return null;
    return AppBar(
      backgroundColor: _C.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        color: Colors.white,
        onPressed: () {
          final p = context.read<PostCubit>().state.post;
          Navigator.pop(context, p);
        },
      ),
      title: post != null
          ? Row(
              children: [
                _MiniAvatar(imageUrl: post.author.avatarUrl, radius: 14),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    post.author.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : null,
      actions: [
        if (post != null) ...[
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 22),
            color: Colors.white,
            onPressed: () => ShareService.sharePost(post),
          ),
          _PostMenuButton(
            isOwner: UserHelper.isPostOwner(context, post),
            post: post,
          ),
        ],
      ],
    );
  }

  Widget _buildBody(BuildContext context, PostCubit cubit) {
    final post = cubit.state.post;
    if (cubit.state.loading) return const _PostViewShimmer();
    if (post == null) {
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: _buildAppBar(context, null),
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
                const Text(
                  'Post not available',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This post may have been removed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _C.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
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

    // In PiP mode: show only the video filling the entire screen.
    // The CustomScrollView / Column structure is replaced with a plain
    // Scaffold whose body IS the video — no appbar, no sliver overhead.
    if (_isInPipMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _PostMedia(
          key: ValueKey('media_${post.id}'),
          post: post,
          pipChannel: _pipChannel,
          fillScreen: true,
        ),
      );
    }

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(context, post),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Media — ALWAYS in tree, NEVER recreated ────────────────
                SliverToBoxAdapter(
                  child: _PostMedia(
                    key: ValueKey('media_${post.id}'),
                    post: post,
                    pipChannel: _pipChannel,
                  ),
                ),

                // ── Everything below — hidden in PiP, state preserved ─────
                SliverToBoxAdapter(
                  child: Visibility(
                    visible: !_isInPipMode,
                    maintainState: true,
                    child: Column(
                      children: [
                        _ActionRow(post: post, cubit: cubit),
                        _Meta(
                          post: post,
                          onStartReply: _startReply,
                          onEditComment: _startEditComment,
                          onDeleteComment: _confirmDeleteComment,
                          cubit: cubit,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Comment input — hidden in PiP
          Visibility(
            visible: !_isInPipMode,
            maintainState: false,
            child: _CommentInputBar(
              controller: _commentController,
              focusNode: _commentFocusNode,
              replyingToCommentId: _replyingToCommentId,
              replyingToUserName: _replyingToUserName,
              editingCommentId: _editingCommentId,
              onCancel: _cancelAction,
              onSubmit: _submitComment,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final Post post;
  final PostCubit cubit;
  const _ActionRow({required this.post, required this.cubit});

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          _AnimatedLikeStat(
            isLiked: post.isLiked,
            count: post.likes,
            onTap: () => cubit.toggleLike(),
          ),
          const SizedBox(width: 20),
          _IconStat(
            icon: Icons.mode_comment_outlined,
            value: _format(post.commentsCount),
            onTap: () {},
          ),
          const SizedBox(width: 20),
          _IconStat(
            icon: Icons.visibility_outlined,
            value: _format(post.views),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => ShareService.sharePost(post),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.ios_share_rounded,
                    color: _C.textSecondary,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Share',
                    style: TextStyle(
                      color: _C.textSecondary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Post media ────────────────────────────────────────────────────────────────
// pipChannel passed in so _PostMediaState can notify native of play state.
// No _isInPipMode here — PiP is handled at screen level via Visibility.

class _PostMedia extends StatefulWidget {
  final Post post;
  final MethodChannel pipChannel;
  final bool fillScreen;
  const _PostMedia({
    super.key,
    required this.post,
    required this.pipChannel,
    this.fillScreen = false,
  });

  @override
  State<_PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<_PostMedia> with WidgetsBindingObserver {
  VideoPlayerController? _vc;
  bool _isVideo = false;
  bool _initialized = false;
  bool _buffering = false;
  bool _muted = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _wasPlayingBeforePause = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isVideo = _detectVideo(widget.post);
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant _PostMedia old) {
    super.didUpdateWidget(old);
    if (old.post.mediaUrl != widget.post.mediaUrl) {
      _disposeVc();
      _isVideo = _detectVideo(widget.post);
      _initVideo();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _disposeVc();
    super.dispose();
  }

  void _disposeVc() {
    _vc?.dispose();
    _vc = null;
  }

  Future<void> _notifyPlayingState(bool playing) async {
    try {
      await widget.pipChannel.invokeMethod('setVideoPlaying', {
        'playing': playing,
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized || _vc == null) return;
    if (state == AppLifecycleState.inactive) {
      if (!_vc!.value.isPlaying) _vc!.play();
      _wasPlayingBeforePause = true;
    } else if (state == AppLifecycleState.paused) {
      _wasPlayingBeforePause = _vc!.value.isPlaying;
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause && !_vc!.value.isPlaying) _vc!.play();
    }
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

  void _initVideo() {
    if (!_isVideo || !_isValidUrl(widget.post.mediaUrl)) return;
    _vc = VideoPlayerController.networkUrl(Uri.parse(widget.post.mediaUrl))
      ..addListener(_onVideoListener)
      ..initialize()
          .then((_) {
            if (!mounted) return;
            setState(() => _initialized = true);
            _vc?.play();
            _vc?.setLooping(true);
            _autoHideControls();
            _notifyPlayingState(true);
          })
          .catchError((_) {});
  }

  void _onVideoListener() {
    if (!mounted) return;
    final b = _vc?.value.isBuffering ?? false;
    if (b != _buffering) setState(() => _buffering = b);
  }

  void _togglePlay() {
    if (!_initialized) return;
    if (_vc!.value.isPlaying) {
      _vc!.pause();
      _controlsTimer?.cancel();
      setState(() => _showControls = true);
      _notifyPlayingState(false);
    } else {
      _vc!.play();
      setState(() => _showControls = true);
      _autoHideControls();
      _notifyPlayingState(true);
    }
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _vc?.setVolume(_muted ? 0 : 1);
    });
  }

  void _autoHideControls() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    if (!_initialized) return;
    if (_showControls) {
      _togglePlay();
    } else {
      setState(() => _showControls = true);
      if (_vc!.value.isPlaying) _autoHideControls();
    }
  }

  void _openFullscreen() {
    if (!_initialized || _vc == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPlayer(controller: _vc!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final mediaHeight = screenW * 0.75;

    // PiP fillScreen mode: pure video that adapts to the PiP window size.
    // SizedBox.expand fills the window; AspectRatio + FittedBox adapts the
    // video to whatever dimensions Android gives the PiP window.
    if (widget.fillScreen) {
      return ColoredBox(
        color: Colors.black,
        child: _initialized && _vc != null
            ? FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _vc!.value.size.width > 0
                      ? _vc!.value.size.width
                      : screenW,
                  height: _vc!.value.size.height > 0
                      ? _vc!.value.size.height
                      : mediaHeight,
                  child: VideoPlayer(_vc!),
                ),
              )
            : const SizedBox.shrink(),
      );
    }

    if (!_isVideo) {
      return SizedBox(
        width: screenW,
        height: mediaHeight,
        child: _isValidUrl(widget.post.mediaUrl)
            ? CachedNetworkImage(
                imageUrl: widget.post.mediaUrl,
                fit: BoxFit.cover,
                width: screenW,
                height: mediaHeight,
                fadeInDuration: const Duration(milliseconds: 250),
                placeholder: (_, __) => ShimmerScope(
                  child: ShimmerBlock(width: screenW, height: mediaHeight),
                ),
                errorWidget: (_, __, ___) => const _MediaPlaceholder(),
              )
            : const _MediaPlaceholder(),
      );
    }

    return SizedBox(
      width: screenW,
      height: mediaHeight,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Shimmer while loading
            if (!_initialized)
              _isValidUrl(widget.post.thumbUrl ?? '')
                  ? CachedNetworkImage(
                      imageUrl: widget.post.thumbUrl!,
                      fit: BoxFit.cover,
                      width: screenW,
                      height: mediaHeight,
                      placeholder: (_, __) => ShimmerScope(
                        child: ShimmerBlock(
                          width: screenW,
                          height: mediaHeight,
                        ),
                      ),
                      errorWidget: (_, __, ___) => ShimmerScope(
                        child: ShimmerBlock(
                          width: screenW,
                          height: mediaHeight,
                        ),
                      ),
                    )
                  : ShimmerScope(
                      child: ShimmerBlock(width: screenW, height: mediaHeight),
                    ),

            // Video
            if (_initialized)
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _vc!.value.size.width,
                    height: _vc!.value.size.height,
                    child: VideoPlayer(_vc!),
                  ),
                ),
              ),

            // Gradient
            const Positioned.fill(
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

            // Full-area tap zone
            Positioned.fill(
              child: GestureDetector(
                onTap: _onTap,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),

            // Buffering
            if (_buffering)
              const Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white70,
                  ),
                ),
              ),

            // Play/pause glyph
            if (_initialized && _showControls && !_buffering)
              Center(
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.55),
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                    child: Icon(
                      _vc!.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Bottom controls
            if (_initialized)
              Positioned(
                left: 12,
                right: 12,
                bottom: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await _notifyPlayingState(true);
                            await widget.pipChannel.invokeMethod('enterPip');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.picture_in_picture_alt_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _openFullscreen,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.fullscreen_rounded,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Scrub bar
            if (_initialized)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  _vc!,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  colors: VideoProgressColors(
                    playedColor: _C.accent,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Fullscreen ────────────────────────────────────────────────────────────────

class _FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullscreenVideoPlayer({required this.controller});

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  bool _showControls = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _autoHide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _autoHide() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _autoHide();
  }

  void _togglePlay() {
    final vc = widget.controller;
    vc.value.isPlaying ? vc.pause() : vc.play();
    setState(() => _showControls = true);
    if (widget.controller.value.isPlaying) _autoHide();
  }

  @override
  Widget build(BuildContext context) {
    final vc = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: vc.value.aspectRatio > 0
                    ? vc.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(vc),
              ),
            ),
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Stack(
                  children: [
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.fullscreen_exit_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.55),
                            border: Border.all(
                              color: Colors.white30,
                              width: 1.5,
                            ),
                          ),
                          child: ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: vc,
                            builder: (_, value, __) => Icon(
                              value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 24,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            VideoProgressIndicator(
                              vc,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              colors: VideoProgressColors(
                                playedColor: _C.accent,
                                bufferedColor: Colors.white38,
                                backgroundColor: Colors.white12,
                              ),
                            ),
                            ValueListenableBuilder<VideoPlayerValue>(
                              valueListenable: vc,
                              builder: (_, value, __) {
                                String fmt(Duration d) =>
                                    '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      fmt(value.position),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      fmt(value.duration),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
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

class _MediaPlaceholder extends StatelessWidget {
  final IconData icon;
  const _MediaPlaceholder({this.icon = Icons.image_rounded});
  @override
  Widget build(BuildContext context) => Container(
    color: _C.border,
    child: Center(child: Icon(icon, color: Colors.white24, size: 36)),
  );
}

class _MiniAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  const _MiniAvatar({required this.imageUrl, required this.radius});
  @override
  Widget build(BuildContext context) {
    final valid =
        imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasScheme == true;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _C.border),
      ),
      child: ClipOval(
        child: valid
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: _C.accent.withOpacity(0.16),
                  child: Icon(
                    Icons.person_rounded,
                    size: radius,
                    color: Colors.white70,
                  ),
                ),
              )
            : Container(
                color: _C.accent.withOpacity(0.16),
                child: Icon(
                  Icons.person_rounded,
                  size: radius,
                  color: Colors.white70,
                ),
              ),
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            ],
          ),
          if (post.caption.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              post.caption,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.tags.map((t) => TagChip(text: t)).toList(),
            ),
          ],
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
                ),
              ),
              if (post.commentsCount > 0)
                Text(
                  '${post.commentsCount} total',
                  style: TextStyle(
                    color: _C.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (cubit.state.comments.isEmpty)
            _buildEmptyComments()
          else
            ...cubit.state.comments.map(
              (c) => _CommentTile(
                comment: c,
                onStartReply: onStartReply,
                onEditComment: onEditComment,
                onDeleteComment: onDeleteComment,
              ),
            ),
          if (cubit.state.commentsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
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

class _AnimatedLikeStat extends StatefulWidget {
  final bool isLiked;
  final int count;
  final VoidCallback onTap;
  const _AnimatedLikeStat({
    required this.isLiked,
    required this.count,
    required this.onTap,
  });
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
                widget.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(widget.isLiked),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 7),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
              child: Text('${widget.count}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final VoidCallback? onTap;
  const _IconStat({required this.icon, required this.value, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _C.textSecondary, size: 19),
            const SizedBox(width: 7),
            Text(
              value,
              style: TextStyle(
                color: _C.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
                    widget.onStartReply(
                      widget.comment.id,
                      widget.comment.user.name,
                    );
                  },
                ),
                if (_isCurrentUserComment) ...[
                  Container(height: 1, color: _C.border),
                  _MenuOption(
                    icon: Icons.edit_rounded,
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
                                child: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 16,
                                  color: Colors.white38,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          c.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Text(
                              timeAgoFrom(c.createdAt),
                              style: TextStyle(
                                color: _C.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(width: 14),
                            _CommentLikeButton(
                              commentId: c.id,
                              isLiked: c.isLiked,
                              likes: c.likes,
                            ),
                            const SizedBox(width: 14),
                            GestureDetector(
                              onTap: () =>
                                  widget.onStartReply(c.id, c.user.name),
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
                          style: TextStyle(
                            color: _C.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
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
    if (mounted) context.read<PostCubit>().toggleCommentLike(widget.commentId);
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
                widget.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(widget.isLiked),
                size: 14,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${widget.likes}',
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showReplyMenu(context),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 14,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reply.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        timeAgoFrom(reply.createdAt),
                        style: TextStyle(color: _C.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                      _CommentLikeButton(
                        commentId: reply.id,
                        isLiked: reply.isLiked,
                        likes: reply.likes,
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
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : Colors.white,
      ),
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

class _PostMenuButton extends StatelessWidget {
  final bool isOwner;
  final Post post;
  const _PostMenuButton({required this.isOwner, required this.post});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async => isOwner
          ? await _showOwnerMenu(context)
          : await _showViewerMenu(context),
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
                  icon: Icons.ios_share_rounded,
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
                  icon: Icons.ios_share_rounded,
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
                    const Text(
                      'Edit Caption',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                      ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
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
                            } catch (_) {}
                          }
                          Navigator.pop(dialogContext);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _C.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
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
          message: 'This action cannot be undone.',
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

class _ConfirmDeleteSheet extends StatelessWidget {
  final String title, message, confirmText;
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
            child: const Icon(
              Icons.delete_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  child: isBusy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          confirmText,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
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
  final String? replyingToCommentId, replyingToUserName, editingCommentId;
  final VoidCallback onCancel, onSubmit;
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
                  editingCommentId != null
                      ? 'Editing comment'
                      : 'Replying to ${replyingToUserName ?? ''}',
                  style: TextStyle(
                    color: _C.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onCancel,
                  child: const Icon(
                    Icons.close_rounded,
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
            Row(
              children: [
                SafeCircleAvatar(
                  imageUrl: currentUserService.getCurrentAvatar(),
                  radius: 18,
                ),
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
                            ? (editingCommentId != null
                                  ? 'Edit your comment...'
                                  : 'Write a reply...')
                            : 'Write a comment...',
                        hintStyle: TextStyle(
                          color: _C.textSecondary,
                          fontSize: 14,
                        ),
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
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onSubmit,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _C.accent,
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
            ),
        ],
      ),
    );
  }
}

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
                  child: Icon(
                    Icons.person_rounded,
                    size: radius,
                    color: Colors.white54,
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: _C.accent.withOpacity(0.16),
                  child: Icon(
                    Icons.person_rounded,
                    size: radius,
                    color: Colors.white70,
                  ),
                ),
              ),
            )
          : ClipOval(
              child: Container(
                color: _C.accent.withOpacity(0.16),
                child: Icon(
                  Icons.person_rounded,
                  size: radius,
                  color: Colors.white70,
                ),
              ),
            ),
    );
    if (onTap == null) return core;
    return GestureDetector(onTap: onTap, child: core);
  }
}

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
              leading: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white54,
              ),
            ),
            SliverToBoxAdapter(
              child: AspectRatio(aspectRatio: 375 / 380, child: ShimmerBlock()),
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
                              ShimmerBone(
                                height: 16,
                                width: 70,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const ShimmerBone(height: 10, width: 40),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        ShimmerBone(width: 60, height: 20),
                        SizedBox(width: 20),
                        ShimmerBone(width: 60, height: 20),
                        SizedBox(width: 20),
                        ShimmerBone(width: 60, height: 20),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const ShimmerBone(height: 13, widthFactor: 1),
                    const SizedBox(height: 7),
                    const ShimmerBone(height: 13, widthFactor: 0.7),
                    const SizedBox(height: 20),
                    Container(height: 1, color: _C.border),
                    const SizedBox(height: 16),
                    ...List.generate(
                      3,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: 18),
                        child: _CommentRowShimmer(),
                      ),
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
