// lib/features/feed/presentation/pages/feed_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/ad_service.dart';
import 'package:moonlight/core/services/video_preload_service.dart'; // ← NEW
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/feed/presentation/widgets/feed_post_card.dart';
import 'package:moonlight/features/feed/presentation/widgets/feed_skeletons.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:visibility_detector/visibility_detector.dart';

// ── Design tokens ────────────────────────────────────────────────────────
class _FeedColors {
  static const bg = Color(0xFF05060F);
  static const surface = Color(0xFF0E1024);
  static const border = Color(0xFF1A1D3D);
  static const accent = Color(0xFFFF6A00);
  static const textSecondary = Color(0xFF8B8FB8);
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scroll = ScrollController();

  // How many items ahead of the current scroll position to keep
  // preloaded. Widened slightly from 3→4 so fast scrolling/flinging
  // still lands on a warmed video more often, without holding so many
  // controllers alive that memory becomes a concern (see
  // VideoPreloadService.maxCached).
  static const int _preloadAhead = 4;
  int _lastPreloadedIndex = -1;

  @override
  void initState() {
    super.initState();

    // VisibilityDetector defaults to checking visibility roughly every
    // 500ms, which reads as "autoplay lagging behind my scroll" on a
    // fast fling. Tightening this makes the play/pause-on-scroll
    // transition track the actual scroll position much more closely.
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 100);

    context.read<FeedCubit>().loadFirstPage();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final c = _scroll.position;
    if (c.pixels > c.maxScrollExtent * 0.7) {
      context.read<FeedCubit>().loadNextPage();
    }
    _maybePreloadUpcoming();
  }

  /// Estimates which feed index is currently near the top of the
  /// viewport and preloads video for the next few items past it. This is
  /// intentionally approximate (based on scroll offset / average item
  /// extent) rather than precise viewport tracking — precision isn't
  /// needed here, we just want to warm "roughly what's coming next."
  void _maybePreloadUpcoming() {
    if (!_scroll.hasClients) return;
    final state = context.read<FeedCubit>().state;
    if (state.items.isEmpty) return;

    // Rough average card extent (media + meta + separator). Doesn't need
    // to be exact — this only decides *when* to trigger preloading, not
    // which items get preloaded (that's index-based below).
    const approxItemExtent = 480.0;
    final estimatedIndex = (_scroll.offset / approxItemExtent).floor();

    if (estimatedIndex <= _lastPreloadedIndex) return;
    _lastPreloadedIndex = estimatedIndex;

    final upcoming = state.items
        .skip(estimatedIndex)
        .take(_preloadAhead)
        .map((p) => p.mediaUrl)
        .where((url) => url.isNotEmpty);

    VideoPreloadService.instance.preloadAll(upcoming);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _FeedColors.bg,
      floatingActionButton: BlocBuilder<FeedCubit, FeedState>(
        buildWhen: (p, n) => p.items.isEmpty != n.items.isEmpty,
        builder: (context, s) {
          if (s.items.isEmpty) return const SizedBox.shrink();
          return const _NewPostFab();
        },
      ),
      body: CustomScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          _FeedAppBar(onRefresh: () => context.read<FeedCubit>().refresh()),
          BlocBuilder<FeedCubit, FeedState>(
            builder: (context, s) {
              if (s.initialLoading) {
                return SliverToBoxAdapter(child: FeedSkeletonList(count: 6));
              }

              if (s.items.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyFeedView(error: s.error),
                );
              }

              // Warm the very first few videos as soon as the feed loads,
              // before the user has scrolled at all — otherwise the first
              // tap of the session gets no preload head start.
              if (s.items.isNotEmpty && _lastPreloadedIndex == -1) {
                _lastPreloadedIndex = 0;
                VideoPreloadService.instance.preloadAll(
                  s.items.take(_preloadAhead).map((p) => p.mediaUrl),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 120),
                sliver: SliverList.separated(
                  itemBuilder: (_, i) {
                    if (i >= s.items.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: FeedSkeletonList(count: 2),
                      );
                    }
                    final post = s.items[i];
                    return FeedPostCard(
                      post: post,
                      onLike: () => context.read<FeedCubit>().toggleLikeAt(i),
                      onOpenPost: () => _openPostAndBump(i, post),
                      onOpenProfile: () => _openProfile(post),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemCount: s.items.length + (s.paging ? 1 : 0),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openPostAndBump(int index, Post p) async {
    context.read<FeedCubit>().incrementViewsAt(index);

    // Tracks the "posts viewed" counter; shows a cached interstitial once
    // every ~9 posts. No-ops instantly if no ad is cached yet — never
    // blocks navigation waiting for an ad to load.
    AdService.instance.onPostViewed();

    final updated = await Navigator.pushNamed(
      context,
      RouteNames.postView,
      arguments: {
        'postId': p.id,
        // Pass the full Post we already have in memory from the feed.
        // PostViewScreen/PostCubit can seed its initial state with this
        // immediately — caption, author, counts, tags all render on the
        // very first frame instead of waiting for a network round trip.
        // The cubit still re-fetches in the background to reconcile any
        // drift (fresh like/comment counts, edits since the feed loaded).
        'initialPost': p,
      },
    );

    if (!mounted) return;
    if (updated is Post) {
      context.read<FeedCubit>().replaceAt(index, updated);
    }
  }

  void _openProfile(Post p) {
    Navigator.pushNamed(
      context,
      RouteNames.profileView,
      arguments: {
        'userUuid': p.author.id.toString(),
        'user_slug': p.author.name,
      },
    );
  }
}

// ── New Post FAB ────────────────────────────────────────────────────────
class _NewPostFab extends StatefulWidget {
  const _NewPostFab();

  @override
  State<_NewPostFab> createState() => _NewPostFabState();
}

class _NewPostFabState extends State<_NewPostFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _widthAnim = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _runEntranceSequence();
  }

  Future<void> _runEntranceSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_disposed) return;

    try {
      await _ctrl.forward().orCancel;
    } catch (_) {
      return;
    }
    if (_disposed) return;

    await Future.delayed(const Duration(milliseconds: 1600));
    if (_disposed) return;

    try {
      await _ctrl.reverse().orCancel;
    } catch (_) {
      return;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ctrl.dispose();
    super.dispose();
  }

  void _go() => Navigator.pushNamed(context, RouteNames.createPost);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _go,
      child: AnimatedBuilder(
        animation: _widthAnim,
        builder: (context, _) {
          final t = _widthAnim.value;
          return Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _FeedColors.accent,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _FeedColors.accent.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: t,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'New post',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                        softWrap: false,
                        overflow: TextOverflow.clip,
                      ),
                    ),
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

// ── Custom app bar ─────────────────────────────────────────────────────────
class _FeedAppBar extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _FeedAppBar({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: _FeedColors.bg,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      toolbarHeight: 64,
      titleSpacing: 18,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'FEED',
            style: TextStyle(
              color: _FeedColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Discover',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.0,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: _RefreshButton(onRefresh: onRefresh),
        ),
      ],
    );
  }
}

class _RefreshButton extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const _RefreshButton({required this.onRefresh});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  bool _busy = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _handle() async {
    if (_busy) return;
    setState(() => _busy = true);
    _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      _spin.stop();
      _spin.reset();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handle,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _FeedColors.surface,
          border: Border.all(color: _FeedColors.border),
        ),
        child: RotationTransition(
          turns: _spin,
          child: Icon(
            Icons.refresh_rounded,
            size: 18,
            color: _busy ? _FeedColors.accent : Colors.white70,
          ),
        ),
      ),
    );
  }
}

// ── Empty / error state ─────────────────────────────────────────────────
class _EmptyFeedView extends StatelessWidget {
  final String? error;
  const _EmptyFeedView({this.error});

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.isNotEmpty;

    return RefreshIndicator(
      color: _FeedColors.accent,
      backgroundColor: _FeedColors.surface,
      onRefresh: () => context.read<FeedCubit>().refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _FeedColors.surface,
                          border: Border.all(color: _FeedColors.border),
                        ),
                        child: Icon(
                          hasError
                              ? Icons.cloud_off_rounded
                              : Icons.auto_awesome_rounded,
                          size: 32,
                          color: hasError ? Colors.white38 : _FeedColors.accent,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        hasError
                            ? "Couldn't load the feed"
                            : 'Nothing here yet',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasError
                            ? 'Something went wrong on our end.\nPull down to try again.'
                            : 'Posts from you and the people you\nfollow will show up here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _FeedColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 26),
                      if (!hasError)
                        _PillButton(
                          label: 'Create a post',
                          icon: Icons.add_rounded,
                          filled: true,
                          onTap: () => Navigator.pushNamed(
                            context,
                            RouteNames.createPost,
                          ),
                        )
                      else
                        _PillButton(
                          label: 'Try again',
                          icon: Icons.refresh_rounded,
                          filled: false,
                          onTap: () => context.read<FeedCubit>().refresh(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _PillButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          color: filled ? _FeedColors.accent : Colors.transparent,
          border: filled
              ? null
              : Border.all(color: Colors.white.withOpacity(0.18)),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}