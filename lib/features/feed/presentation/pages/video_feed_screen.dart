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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/video_preload_service.dart';
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/feed/presentation/widgets/feed_post_card.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:moonlight/features/post_view/domain/repositories/post_repository.dart';
import 'package:moonlight/features/post_view/presentation/widgets/comment_bottom_sheet.dart';

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
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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
                bottom: 24,
                child: BlocBuilder<FeedCubit, FeedState>(
                  buildWhen: (p, n) => p.items != n.items,
                  builder: (context, state) {
                    final current =
                        originalIndex >= 0 && originalIndex < state.items.length
                        ? state.items[originalIndex]
                        : post;
                    return Column(
                      children: [
                        _VideoActionButton(
                          icon: current.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: current.isLiked ? Colors.red : Colors.white,
                          label: '${current.likes}',
                          onTap: () => context.read<FeedCubit>().toggleLikeAt(
                            originalIndex,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _VideoActionButton(
                          icon: Icons.mode_comment_rounded,
                          color: Colors.white,
                          label: '${current.commentsCount}',
                          onTap: () => CommentBottomSheet.show(
                            context,
                            postId: current.id,
                            initialPost: current,
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(height: 20),
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
            ],
          );
            },
          );
        },
      ),
    );
  }
}

class _VideoActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _VideoActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
