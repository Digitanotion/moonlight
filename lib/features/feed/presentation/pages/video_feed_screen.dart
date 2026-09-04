// lib/features/feed/presentation/pages/video_feed_screen.dart
//
// Doc item 5: "Videos on posts will be scrollable so that users can
// scroll videos just like on Facebook with likes, comments, reply and
// edit by the side with description but image posts won't be."
//
// Full-screen, vertical PageView — one video per page, autoplay/loop
// via the reused FeedVideoPlayer, action icons stacked on the right
// (like / comment-with-reply / edit-if-owner), author + caption at
// bottom-left. Must be provided the SAME FeedCubit instance the caller
// is already using (via BlocProvider.value at the navigation site) so
// likes stay in sync with the regular feed rather than diverging.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/share_service.dart';
import 'package:moonlight/core/services/video_preload_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/feed/presentation/widgets/feed_post_card.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:moonlight/features/post_view/domain/entities/user.dart';
import 'package:moonlight/features/post_view/domain/repositories/post_repository.dart';
import 'package:moonlight/features/post_view/presentation/widgets/comment_bottom_sheet.dart';
import 'package:moonlight/features/profile_view/domain/repositories/profile_repository.dart';
import 'package:moonlight/widgets/top_snack.dart';

class VideoFeedScreen extends StatefulWidget {
  // Seed list captured at navigation time. The screen no longer treats
  // this as the whole world — it re-derives the live video list from the
  // shared FeedCubit on every build and paginates that cubit as the user
  // approaches the end, so the swipe flow reaches every video the feed
  // can load, not just the handful already on screen when it opened.
  final List<Post> videoPosts;
  final List<int> originalIndices;
  final int initialIndex;

  const VideoFeedScreen({
    super.key,
    required this.videoPosts,
    required this.originalIndices,
    required this.initialIndex,
  });

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late final PageController _pageController;

  // Only warms the on-disk byte cache now (no decoders), but each warm is a
  // full video download — keep the window small so they don't saturate the
  // connection and so back-scroll stays cheap. Biased forward.
  static const int _preloadAhead = 2;
  static const int _preloadBehind = 1;
  // How close to the end of the loaded videos the user must get before we
  // ask the feed for the next page.
  static const int _paginateThreshold = 3;

  // Shared across every video in this swipe flow — toggling sound on any
  // one video affects all the others too, matching how TikTok itself
  // behaves, rather than each video resetting to muted independently.
  bool _muted = true;

  int _currentIndex = 0;

  // Live videos-only view of the FeedCubit's items, plus each entry's
  // index within the cubit's full list (needed for index-based
  // toggleLikeAt / replaceAt). Recomputed from cubit state each build.
  List<Post> _videoPosts = const [];
  List<int> _originalIndices = const [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _videoPosts = List.of(widget.videoPosts);
    _originalIndices = List.of(widget.originalIndices);
    _pageController = PageController(initialPage: widget.initialIndex);
    _preloadAround(widget.initialIndex);
  }

  /// Rebuild the videos-only projection from the cubit's current items.
  void _syncFromFeed(FeedState state) {
    final posts = <Post>[];
    final indices = <int>[];
    for (var i = 0; i < state.items.length; i++) {
      if (state.items[i].isVideo) {
        posts.add(state.items[i]);
        indices.add(i);
      }
    }
    _videoPosts = posts;
    _originalIndices = indices;
  }

  /// Ask the feed for more if the user is within [_paginateThreshold]
  /// pages of the last loaded video. Safe to call repeatedly — the cubit
  /// no-ops while already paging or when there's nothing left.
  void _maybePaginate() {
    if (_currentIndex >= _videoPosts.length - 1 - _paginateThreshold) {
      final cubit = context.read<FeedCubit>();
      if (cubit.state.hasMore && !cubit.state.paging) {
        cubit.loadNextPage();
      }
    }
  }

  void _preloadAround(int index) {
    final urls = <String>[];
    for (var offset = 1; offset <= _preloadAhead; offset++) {
      final nextIdx = index + offset;
      if (nextIdx < _videoPosts.length) urls.add(_videoPosts[nextIdx].mediaUrl);
    }
    for (var offset = 1; offset <= _preloadBehind; offset++) {
      final prevIdx = index - offset;
      if (prevIdx >= 0) urls.add(_videoPosts[prevIdx].mediaUrl);
    }
    VideoPreloadService.instance.preloadAll(urls);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _editCaption(BuildContext context, Post post) async {
    final controller = TextEditingController(text: post.caption);
    final newCaption = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1024),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit caption',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(sheetContext).pop(controller.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A00),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (newCaption == null ||
        newCaption.isEmpty ||
        newCaption == post.caption) {
      return;
    }
    try {
      await sl<PostRepository>().editCaption(post.id, newCaption);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Caption updated')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update caption')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<FeedCubit, FeedState>(
        listenWhen: (p, n) =>
            p.items.length != n.items.length || p.paging != n.paging,
        listener: (context, state) {
          // A page just landed — if the user is still near the end (e.g.
          // the new page was mostly images), keep pulling until there's
          // a comfortable runway of videos ahead or the feed is exhausted.
          if (!state.paging) {
            _syncFromFeed(state);
            _maybePaginate();
          }
        },
        builder: (context, state) {
          _syncFromFeed(state);

          if (_videoPosts.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _videoPosts.length,
            onPageChanged: (i) {
              _currentIndex = i;
              _preloadAround(i);
              _maybePaginate();
            },
            itemBuilder: (context, i) {
              final post = _videoPosts[i];
              final originalIndex = _originalIndices[i];
              final isOwner =
                  post.author.id == sl<CurrentUserService>().currentUser?.id;

              final double safeBottom = MediaQuery.of(context).padding.bottom;
              // Height of the fixed comment bar, measured from the bottom
              // edge — everything else stacks above it.
              final double commentBarHeight = safeBottom + 56;

              return Stack(
                fit: StackFit.expand,
                children: [
                  FeedVideoPlayer(
                    post: post,
                    onOpenPost: () {},
                    enableTapToPlayPause: true,
                    muteIconTopOffset: MediaQuery.of(context).padding.top + 10,
                    initialMuted: _muted,
                    onMuteChanged: (muted) => setState(() => _muted = muted),
                    onAspectKnown: (_) {},
                    showProgressBar: true,
                    progressBarBottomInset: commentBarHeight,
                  ),

                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  Positioned(
                    left: 16,
                    right: 88,
                    bottom: commentBarHeight + 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: post.author.id.isEmpty
                              ? null
                              : () => Navigator.of(context).pushNamed(
                                  RouteNames.profileView,
                                  arguments: {'userUuid': post.author.id},
                                ),
                          child: Text(
                            post.author.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (post.caption.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            post.caption,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  Positioned(
                    right: 12,
                    bottom: commentBarHeight + 16,
                    child: BlocBuilder<FeedCubit, FeedState>(
                      buildWhen: (p, n) => p.items != n.items,
                      builder: (context, state) {
                        final current =
                            originalIndex >= 0 &&
                                originalIndex < state.items.length
                            ? state.items[originalIndex]
                            : post;
                        return Column(
                          children: [
                            _FollowAvatarButton(
                              key: ValueKey('follow_${current.author.id}'),
                              author: current.author,
                              isOwner: isOwner,
                            ),
                            const SizedBox(height: 22),
                            _VideoActionButton(
                              icon: current.isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: current.isLiked
                                  ? const Color(0xFFFF3B5C)
                                  : Colors.white,
                              tint: current.isLiked
                                  ? const Color(0xFFFF3B5C).withOpacity(0.16)
                                  : null,
                              label: '${current.likes}',
                              onTap: () => context
                                  .read<FeedCubit>()
                                  .toggleLikeAt(originalIndex),
                            ),
                            const SizedBox(height: 18),
                            _VideoActionButton(
                              icon: Icons.mode_comment_rounded,
                              color: Colors.white,
                              label: '${current.commentsCount}',
                              onTap: () => CommentBottomSheet.show(
                                context,
                                postId: current.id,
                                initialPost: current,
                                onCountChanged: (n) => context
                                    .read<FeedCubit>()
                                    .setCommentsCountAt(originalIndex, n),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _VideoActionButton(
                              icon: Icons.redo_rounded,
                              color: Colors.white,
                              label: 'Share',
                              onTap: () => ShareService.sharePost(current),
                            ),
                            if (isOwner) ...[
                              const SizedBox(height: 18),
                              _VideoActionButton(
                                icon: Icons.edit_rounded,
                                color: Colors.white,
                                label: 'Edit',
                                onTap: () => _editCaption(context, current),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),

                  // Fixed, slightly-transparent "Add a comment" bar.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: BlocBuilder<FeedCubit, FeedState>(
                      buildWhen: (p, n) => p.items != n.items,
                      builder: (context, state) {
                        final current =
                            originalIndex >= 0 &&
                                originalIndex < state.items.length
                            ? state.items[originalIndex]
                            : post;
                        return _VideoCommentBar(
                          bottomInset: safeBottom,
                          onTap: () => CommentBottomSheet.show(
                            context,
                            postId: current.id,
                            initialPost: current,
                            onCountChanged: (n) => context
                                .read<FeedCubit>()
                                .setCommentsCountAt(originalIndex, n),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Reusable "press to shrink, release to spring back" wrapper — gives every
/// tappable icon in the rail the same elegant, TikTok-style tactile feel
/// without duplicating an AnimationController in each widget.
class _TapBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const _TapBounce({
    required this.child,
    required this.onTap,
    this.scaleDown = 0.86,
    super.key,
  });

  @override
  State<_TapBounce> createState() => _TapBounceState();
}

class _TapBounceState extends State<_TapBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
    reverseCurve: Curves.elasticOut,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _c.forward(),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              _c.reverse();
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onTapCancel: widget.onTap == null ? null : () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: 1 - (_scale.value * (1 - widget.scaleDown)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Modern, elegant translucent "glass" chip used for like / comment / share /
/// edit. Every icon animates on touch via [_TapBounce]; an optional [tint]
/// lets liked/active states glow softly instead of just swapping color.
class _VideoActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final Color? tint;

  const _VideoActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return _TapBounce(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint ?? Colors.white.withOpacity(0.10),
              border: Border.all(
                color: Colors.white.withOpacity(0.16),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

/// TikTok-style circular "author avatar as a follow button" — the post
/// author's photo fills a translucent circle; a small "+" badge sits on its
/// bottom-right. Tapping the badge optimistically follows the author with a
/// "+" → check-mark morph animation, then permanently fades the badge away.
/// Tapping the avatar itself opens the author's profile. Hidden entirely for
/// the post owner or once the viewer already follows them.
class _FollowAvatarButton extends StatefulWidget {
  final AppUser author;
  final bool isOwner;

  const _FollowAvatarButton({
    required this.author,
    required this.isOwner,
    super.key,
  });

  @override
  State<_FollowAvatarButton> createState() => _FollowAvatarButtonState();
}

class _FollowAvatarButtonState extends State<_FollowAvatarButton> {
  // Source of truth is the FeedCubit's own item (widget.author.isFollowing),
  // NOT local state — a video page can be disposed and recreated as the
  // user swipes past and back, which would otherwise forget the follow.
  // _justFollowed only drives the brief "+"→check animation while the
  // request is in flight and the cubit hasn't confirmed it yet.
  bool _busy = false;
  bool _justFollowed = false;

  void _openProfile() {
    final id = widget.author.id;
    if (id.isEmpty) return;
    Navigator.of(
      context,
    ).pushNamed(RouteNames.profileView, arguments: {'userUuid': id});
  }

  Future<void> _follow() async {
    if (_busy || widget.author.isFollowing) return;
    setState(() {
      _busy = true;
      _justFollowed = true; // optimistic: flips the badge to a check now
    });
    try {
      await sl<ProfileRepository>().followUser(widget.author.id);
      if (!mounted) return;
      // Flip the shared feed state now so every card by this author (and
      // this widget if it gets rebuilt/remounted) reflects it permanently.
      context.read<FeedCubit>().markAuthorFollowed(widget.author.id);
      // Hold the check mark briefly so the animation reads clearly before
      // the badge fades away.
      await Future.delayed(const Duration(milliseconds: 650));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _justFollowed = false;
        _busy = false;
      });
      TopSnack.error(context, 'Could not follow. Try again.');
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOwner) return const SizedBox.shrink();

    final showBadge = !widget.author.isFollowing;
    final avatarUrl = widget.author.avatarUrl;

    return _TapBounce(
      onTap: _openProfile,
      scaleDown: 0.9,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.55),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: Container(
                  color: Colors.white.withOpacity(0.14),
                  child: avatarUrl.isEmpty
                      ? _AuthorInitials(name: widget.author.name)
                      : CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              _AuthorInitials(name: widget.author.name),
                          placeholder: (_, _) =>
                              _AuthorInitials(name: widget.author.name),
                        ),
                ),
              ),
            ),
            // Positioned must sit directly under Stack — the fade lives on
            // the badge's own child instead, so Flutter never rejects this
            // as a misplaced ParentDataWidget.
            Positioned(
              right: -2,
              bottom: -2,
              child: IgnorePointer(
                ignoring: !showBadge,
                child: AnimatedOpacity(
                  opacity: showBadge ? 1 : 0,
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOut,
                  child: _TapBounce(
                    onTap: showBadge ? _follow : null,
                    scaleDown: 0.78,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: Colors.black, width: 1.6),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          _justFollowed
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                          key: ValueKey(_justFollowed),
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorInitials extends StatelessWidget {
  final String name;

  const _AuthorInitials({required this.name});

  static const _palette = [
    Color(0xFFFF6B6B),
    Color(0xFFFFA94D),
    Color(0xFFFFD43B),
    Color(0xFF69DB7C),
    Color(0xFF4DABF7),
    Color(0xFF9775FA),
    Color(0xFFF783AC),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final hash = trimmed.codeUnits.fold<int>(0, (a, b) => a + b);
    final color = _palette[hash % _palette.length];
    return Container(
      alignment: Alignment.center,
      color: color.withOpacity(0.9),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Fixed, faintly-transparent composer strip pinned to the bottom of the
/// fullscreen video. Tapping anywhere on it opens the comment sheet (which
/// carries the real composer + thread). Deliberately a lightweight
/// affordance rather than a live inline field, so it can't get out of sync
/// with the sheet's own state.
class _VideoCommentBar extends StatelessWidget {
  final double bottomInset;
  final VoidCallback onTap;

  const _VideoCommentBar({required this.bottomInset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 8, 14, bottomInset + 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0),
              Colors.black.withOpacity(0.55),
            ],
          ),
        ),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Add a comment…',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.send_rounded,
                color: Colors.white.withOpacity(0.9),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
