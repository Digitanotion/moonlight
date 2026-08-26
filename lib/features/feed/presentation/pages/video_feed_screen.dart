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
  final List<Post> videoPosts;
  // Parallel to videoPosts — each entry is that video's index within
  // the FeedCubit's own full, unfiltered items list, needed because
  // FeedCubit.toggleLikeAt() is index-based against that full list,
  // not against our filtered videos-only list here.
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

  static const int _preloadWindow = 4; // matches TikTok-style "few ahead" feel

  // Shared across every video in this swipe flow — toggling sound on any
  // one video affects all the others too, matching how TikTok itself
  // behaves, rather than each video resetting to muted independently.
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _preloadAround(widget.initialIndex);
  }

  void _preloadAround(int index) {
    final urls = <String>[];
    for (var offset = 1; offset <= _preloadWindow; offset++) {
      final nextIdx = index + offset;
      final prevIdx = index - offset;
      if (nextIdx < widget.videoPosts.length) {
        urls.add(widget.videoPosts[nextIdx].mediaUrl);
      }
      if (prevIdx >= 0) {
        urls.add(widget.videoPosts[prevIdx].mediaUrl);
      }
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
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videoPosts.length,
        onPageChanged: (i) => _preloadAround(i),
        itemBuilder: (context, i) {
          final post = widget.videoPosts[i];
          final originalIndex = widget.originalIndices[i];
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
