import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/profile_view/presentation/cubit/profile_cubit.dart';
import 'package:moonlight/core/routing/route_names.dart';

class ProfileViewPage extends StatefulWidget {
  const ProfileViewPage({super.key});

  @override
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  int _tabIndex = 0;
  String? _userUuid;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // read args
    final a = (ModalRoute.of(context)?.settings.arguments as Map?) ?? const {};
    final uuid = a['userUuid'] as String?;
    if (uuid != null && uuid != _userUuid) {
      _userUuid = uuid;
      context.read<ProfileCubit>().load(uuid);
    }
  }

  void _onScroll() {
    if (_userUuid == null) return;
    final p = _scroll.position;
    if (p.pixels > p.maxScrollExtent * 0.75) {
      context.read<ProfileCubit>().loadMore(_userUuid!);
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
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, s) {
              final user = s.user;
              return CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    floating: true,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.more_horiz, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF1B2153), Color(0xFF0F1432)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 33,
                              backgroundImage:
                                  (user?.avatarUrl.isNotEmpty == true)
                                  ? CachedNetworkImageProvider(user!.avatarUrl)
                                  : null,
                              backgroundColor: Colors.black12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            user?.handle ?? '@user',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?.fullName ?? '',
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _BadgePill(label: 'Member'),
                          const SizedBox(height: 14),
                          if ((user?.bio ?? '').isNotEmpty)
                            Text(
                              user!.bio,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white70,
                                height: 1.45,
                              ),
                            ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _PrimaryButton(
                                  text: 'Follow',
                                  onPressed: () {},
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _OutlineButton(
                                  text: 'Message',
                                  onPressed: () {},
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _StatsCard(
                        stats: [
                          _Stat(
                            label: 'Fans',
                            value: '${user?.followers ?? 0}',
                          ),
                          _Stat(
                            label: 'Following',
                            value: '${user?.following ?? 0}',
                          ),
                          const _Stat(label: 'Live Sessions', value: '—'),
                          const _Stat(label: 'Coins', value: '—'),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _Tabs(
                        index: _tabIndex,
                        onChanged: (i) => setState(() => _tabIndex = i),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  if (_tabIndex == 0)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: _PostsGrid(
                        posts: s.posts,
                        loading: s.loadingPosts,
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _PlaceholderCard(
                          text: _tabIndex == 1
                              ? 'No clubs yet'
                              : 'No live replays yet',
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 90)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.text, required this.onPressed});
  final String text;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF7A00),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.text, required this.onPressed});
  final String text;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.25), width: 1.2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA726),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircleAvatar(
            radius: 9,
            backgroundColor: Colors.white,
            child: Icon(Icons.verified, size: 14, color: Color(0xFF8B4C00)),
          ),
          SizedBox(width: 8),
          Text(
            'Member',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final List<_Stat> stats;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B2153), Color(0xFF0F1432)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: stats
            .map((s) => Expanded(child: _StatItem(stat: s)))
            .toList(),
      ),
    );
  }
}

class _Stat {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.stat});
  final _Stat stat;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          stat.value,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          stat.label,
          style: AppTextStyles.small.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final labels = const ['Posts', 'Clubs', 'Live Replays'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = index == i;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFF7A00)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PostsGrid extends StatelessWidget {
  const _PostsGrid({required this.posts, required this.loading});
  final List posts;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty && loading) {
      // simple skeleton grid
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate((_, __) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
          );
        }, childCount: 9),
      );
    }
    if (posts.isEmpty) {
      return SliverToBoxAdapter(child: _PlaceholderCard(text: 'No posts yet'));
    }
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final p = posts[index];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            RouteNames.postView,
            arguments: {'postId': p.id, 'isOwner': false},
          ),
          child: Hero(
            tag: 'post_${p.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: p.mediaUrl,
                fit: BoxFit.cover,
                placeholder: (c, _) => Container(color: Colors.white12),
              ),
            ),
          ),
        );
      }, childCount: posts.length),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: AppTextStyles.body.copyWith(color: Colors.white70),
      ),
    );
  }
}
