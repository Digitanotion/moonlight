// lib/features/home/presentation/widgets/home_discover_grid.dart
//
// Replaces the lives-only LiveNowSection on Home. Solves the cold-start
// problem — a brand-new install with nobody live yet used to show an empty
// grid, which reads as a dead app. Now: live streams first (unchanged
// behavior, unchanged LiveFeedBloc, unchanged LiveTileGrid), then video
// posts fill the rest via a ranked (engagement + social + interest) feed,
// paginated until every eligible video has been shown.
//
// LiveNowSection/LiveFeedBloc themselves are NOT modified — this is a new,
// separate widget so the existing lives-only flow stays fully intact and
// revertible if ever needed elsewhere.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/feed/domain/repositories/feed_repository.dart';
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/feed/presentation/pages/video_feed_screen.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_bloc.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_event.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_state.dart';
import 'package:moonlight/features/home/presentation/widgets/live_tile_grid.dart';
import 'package:moonlight/features/home/presentation/widgets/shimmer.dart';
import 'package:moonlight/features/home/presentation/widgets/video_tile_grid.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';

class HomeDiscoverGrid extends StatefulWidget {
  const HomeDiscoverGrid({super.key});
  @override
  State<HomeDiscoverGrid> createState() => _HomeDiscoverGridState();
}

class _HomeDiscoverGridState extends State<HomeDiscoverGrid> {
  final _ctrl = ScrollController();
  late final FeedCubit _videoCubit;

  @override
  void initState() {
    super.initState();
    // Same LiveFeedBloc instance/event LiveNowSection used to start with —
    // that bloc itself is untouched, just driven from here now instead.
    context.read<LiveFeedBloc>().add(LiveFeedStarted(order: 'trending'));
    // Own FeedCubit instance, own pagination state — completely separate
    // from whatever instance the Posts screen is using.
    _videoCubit = FeedCubit(
      sl<FeedRepository>(),
      type: 'video',
      sort: 'trending',
    )..loadFirstPage();
    _ctrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_ctrl.position.pixels >= _ctrl.position.maxScrollExtent - 400) {
      context.read<LiveFeedBloc>().add(LiveFeedLoadMore());
      _videoCubit.loadNextPage();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _videoCubit.close();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    context.read<LiveFeedBloc>().add(LiveFeedRefresh());
    await _videoCubit.refresh();
  }

  void _openVideo(List<Post> videos, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _videoCubit,
          child: VideoFeedScreen(
            videoPosts: videos,
            // Every item in this cubit's state IS a video (server-filtered
            // via type=video), so the index mapping is the identity — no
            // photo/video filtering needed like the mixed Posts feed does.
            originalIndices: List.generate(videos.length, (i) => i),
            initialIndex: index,
          ),
        ),
      ),
    );
  }

  int _calcColumns(double width) {
    if (width >= 1100) return 4;
    if (width >= 800) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BlocProvider.value(
        value: _videoCubit,
        child: BlocBuilder<FeedCubit, FeedState>(
          builder: (context, videoState) {
            return BlocBuilder<LiveFeedBloc, LiveFeedState>(
              builder: (context, liveState) {
                final lives = liveState.items;
                final videos = videoState.items;

                final stillLoadingFirstBatch =
                    lives.isEmpty &&
                    videos.isEmpty &&
                    (liveState.status == LiveFeedStatus.loading ||
                        liveState.status == LiveFeedStatus.initial ||
                        videoState.initialLoading);

                if (stillLoadingFirstBatch) {
                  return const _ShimmerGrid();
                }

                final nothingToShow =
                    lives.isEmpty &&
                    videos.isEmpty &&
                    !stillLoadingFirstBatch &&
                    !videoState.paging;

                if (nothingToShow) {
                  return _EmptyDiscoverState(onRefresh: _onRefresh);
                }

                final totalCount =
                    lives.length + videos.length + (videoState.paging ? 1 : 0);

                return LayoutBuilder(
                  builder: (_, box) {
                    final cols = _calcColumns(box.maxWidth);
                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: GridView.builder(
                        controller: _ctrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          childAspectRatio: 9 / 13,
                        ),
                        itemCount: totalCount,
                        itemBuilder: (context, i) {
                          // Lives always first, unchanged widget/behavior.
                          if (i < lives.length) {
                            return LiveTileGrid(
                              item: lives[i],
                              items: lives,
                              index: i,
                            );
                          }
                          final videoIndex = i - lives.length;
                          if (videoIndex >= videos.length) {
                            return const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return VideoTileGrid(
                            post: videos[videoIndex],
                            onTap: () => _openVideo(videos, videoIndex),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) {
        int cols = 2;
        if (box.maxWidth >= 1100) {
          cols = 4;
        } else if (box.maxWidth >= 800) {
          cols = 3;
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 9 / 13,
          ),
          itemCount: cols * 3,
          itemBuilder: (_, _) => Shimmer(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyDiscoverState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyDiscoverState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_outlined,
              color: Colors.white.withValues(alpha: 0.3),
              size: 44,
            ),
            const SizedBox(height: 14),
            const Text(
              'Nothing here yet',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check back soon, or pull down to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRefresh, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}
