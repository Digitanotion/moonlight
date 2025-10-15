import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/feed/presentation/widgets/feed_post_card.dart';
import 'package:moonlight/features/feed/presentation/widgets/feed_skeletons.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<FeedCubit>().loadFirstPage();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final c = _scroll.position;
    if (c.pixels > c.maxScrollExtent * 0.7) {
      context.read<FeedCubit>().loadNextPage();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1E5F), Color(0xFF0A0B12)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text(
            'Explore',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          centerTitle: false,
          elevation: 0,
        ),
        body: BlocBuilder<FeedCubit, FeedState>(
          builder: (context, s) {
            if (s.initialLoading) return const FeedSkeletonList(count: 8);

            return RefreshIndicator(
              onRefresh: () => context.read<FeedCubit>().refresh(),
              child: ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                itemBuilder: (_, i) {
                  if (i >= s.items.length) {
                    // paging skeletons
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: FeedSkeletonList(count: 3),
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
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: s.items.length + (s.paging ? 1 : 0),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openPostAndBump(int index, Post p) async {
    // optimistic +1 view
    context.read<FeedCubit>().incrementViewsAt(index);

    final updated = await Navigator.pushNamed(
      context,
      RouteNames.postView,
      arguments: {
        'postId': p.id, // <- keep using .id
        'isOwner': false,
      },
    );

    if (!mounted) return;
    if (updated is Post) {
      context.read<FeedCubit>().replaceAt(index, updated);
    }
  }

  // void _openPost(Post p) {
  //   Navigator.pushNamed(
  //     context,
  //     RouteNames.postView,
  //     arguments: {'postId': p.id, 'isOwner': false},
  //   );
  // }

  void _openProfile(Post p) {
    Navigator.pushNamed(
      context,
      RouteNames.profile_view,
      arguments: {
        'userUuid': p.author.id.toString(),
        'user_slug': p.author.name,
      }, // id isn’t used; router takes uuid via args (see patch below)
    );
  }
}
