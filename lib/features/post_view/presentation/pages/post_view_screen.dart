// lib/features/post_view/presentation/pages/post_view_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/post_view/presentation/pages/comments_page.dart';
import 'package:moonlight/features/post_view/presentation/widgets/skeleton_line_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:video_player/video_player.dart'; // ⬅️ NEW
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/time_ago.dart';
import '../../domain/entities/post.dart';
import '../cubit/post_cubit.dart';
import '../widgets/chips.dart';
import '../widgets/sheets.dart';

class PostViewScreen extends StatelessWidget {
  final bool isOwner;
  const PostViewScreen({super.key, this.isOwner = false});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PostCubit>();
    final post = cubit.state.post;

    return WillPopScope(
      onWillPop: () async {
        final p = cubit.state.post;
        Navigator.pop(context, p); // return current post state to caller
        return false;
      },
      child: _buildBody(context, cubit),
    );
  }

  Widget _buildBody(BuildContext context, PostCubit cubit) {
    final post = cubit.state.post;
    if (cubit.state.loading) return const _PostViewShimmer();
    if (post == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Post not found')),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _Body(key: ValueKey(post.id), post: post, isOwner: isOwner),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Post post;
  final bool isOwner;
  const _Body({super.key, required this.post, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Stack(
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
            // ⬇️ MEDIA AREA: image or video with hero
            SliverToBoxAdapter(
              child: Hero(
                tag: 'post_${post.id}', // matches FeedPostCard
                child: _PostMedia(post: post),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                child: _Meta(post: post, isOwner: isOwner),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- Media widget: handles image OR video ---
class _PostMedia extends StatefulWidget {
  final Post post;
  const _PostMedia({required this.post});

  @override
  State<_PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<_PostMedia> {
  VideoPlayerController? _vc;
  bool _isVideo = false;
  bool _showGlyph = true; // show play/pause glyph briefly on state changes

  bool get _isInitialized => _vc?.value.isInitialized == true;

  @override
  void initState() {
    super.initState();
    _isVideo = _detectVideo(widget.post);
    if (_isVideo) {
      _vc = VideoPlayerController.networkUrl(Uri.parse(widget.post.mediaUrl))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _vc?.play();
          _vc?.setLooping(true);
          _flashGlyph(); // show play glyph briefly on auto-play
        });
    }
  }

  @override
  void didUpdateWidget(covariant _PostMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.mediaUrl != widget.post.mediaUrl) {
      _disposeVc();
      _isVideo = _detectVideo(widget.post);
      if (_isVideo) {
        _vc = VideoPlayerController.networkUrl(Uri.parse(widget.post.mediaUrl))
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() {});
            _vc?.play();
            _vc?.setLooping(true);
            _flashGlyph();
          });
      }
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

  String get _previewUrl {
    // Prefer thumb for video; else mediaUrl (works for image too)
    return (widget.post.thumbUrl?.isNotEmpty == true)
        ? widget.post.thumbUrl!
        : widget.post.mediaUrl;
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
    // Default aspect ratio to your old one until we know the video’s real ratio
    final defaultAspect = 375 / 380;

    if (!_isVideo) {
      // Image path (unchanged visuals)
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

    // Video path
    final ar = _isInitialized
        ? (_vc!.value.aspectRatio > 0 ? _vc!.value.aspectRatio : defaultAspect)
        : defaultAspect;

    return AspectRatio(
      aspectRatio: ar,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // While loading (or as preview), show thumb/preview
          if (!_isInitialized)
            CachedNetworkImage(
              imageUrl: _previewUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.white10),
              errorWidget: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),

          // Once ready, show the video
          if (_isInitialized) VideoPlayer(_vc!),

          // Tap area — toggle play/pause
          Material(
            color: Colors.transparent,
            child: InkWell(onTap: _togglePlay),
          ),

          // Subtle bottom gradient for contrast
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

          // Center glyph (play/pause) shown briefly
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

          // Bottom progress bar
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

// --- shimmer skeleton screen ---
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
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  pinned: false,
                  floating: true,
                  leading: IconButton(
                    onPressed: () {}, // disabled in skeleton
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(radius: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    SkeletonLine(widthFactor: .5, height: 12),
                                    SizedBox(height: 6),
                                    SkeletonPill(width: 80, height: 18),
                                  ],
                                ),
                              ),
                              const SkeletonLine(width: 40, height: 12),
                              const SizedBox(width: 6),
                              const Icon(Icons.more_horiz),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const SkeletonLine(height: 12),
                          const SizedBox(height: 6),
                          const SkeletonLine(widthFactor: .8, height: 12),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              SkeletonPill(width: 64, height: 22),
                              SkeletonPill(width: 56, height: 22),
                              SkeletonPill(width: 72, height: 22),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: const [
                              Icon(Icons.favorite_border),
                              SizedBox(width: 18),
                              Icon(Icons.mode_comment_outlined),
                              SizedBox(width: 18),
                              Icon(Icons.share_outlined),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: AppColors.divider),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              SkeletonLine(width: 100, height: 16),
                              SkeletonLine(width: 120, height: 16),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (int i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  CircleAvatar(radius: 14),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SkeletonLine(
                                          widthFactor: .4,
                                          height: 12,
                                        ),
                                        SizedBox(height: 4),
                                        SkeletonLine(height: 12),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

class _Meta extends StatelessWidget {
  final Post post;
  final bool isOwner;
  const _Meta({required this.post, required this.isOwner});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(post.author.avatarUrl),
                radius: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.author.name,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
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
              IconButton(
                onPressed: () async {
                  if (isOwner) {
                    await showOwnerMenuSheet(
                      context,
                      onDelete: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Post deleted (mock')),
                        );
                        Navigator.pop(context);
                      },
                      onEdit: (caption) =>
                          context.read<PostCubit>().editCaption(caption),
                    );
                  } else {
                    await showViewerMenuSheet(
                      context,
                      onReport: () async {
                        final cubit = context.read<PostCubit>();
                        final reason = await pickReason(context);
                        if (reason == null) return;
                        try {
                          await cubit.repo.report(cubit.postId, reason);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Thanks for reporting. We’ll review it.',
                              ),
                            ),
                          );
                        } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not report right now.'),
                            ),
                          );
                        }
                      },
                      onCopy: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.more_horiz),
              ),
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
                value: post.likes,
                onTap: () => context.read<PostCubit>().toggleLike(),
                active: post.isLiked,
              ),
              const SizedBox(width: 18),
              _IconStat(
                icon: Icons.mode_comment_outlined,
                value: post.commentsCount,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<PostCubit>(),
                      child: const CommentsPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              _IconStat(
                icon: Icons.share_outlined,
                value: post.shares,
                onTap: () => showShareSheet(
                  context,
                  url: 'https://moonlight.app/post/${post.id}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 8),

          // Header + View All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Comments',
                style: AppTextStyles.titleMedium.copyWith(fontSize: 16),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<PostCubit>(),
                        child: const CommentsPage(),
                      ),
                    ),
                  );
                },
                child: const Text('View All Comments'),
              ),
            ],
          ),

          // First 3 comments preview
          Builder(
            builder: (context) {
              final comments = context.watch<PostCubit>().state.comments;
              final preview = comments.take(3).toList();
              if (preview.isEmpty) return const SizedBox.shrink();
              return Column(
                children: preview.map((c) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: NetworkImage(c.user.avatarUrl),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.user.name,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(c.text, style: AppTextStyles.body),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IconStat extends StatelessWidget {
  final IconData icon;
  final int value;
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
