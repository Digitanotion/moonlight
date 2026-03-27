// lib/features/profile_view/presentation/pages/follow_list_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/profile_view/data/datasources/follow_list_remote_datasource.dart';
import 'package:moonlight/features/profile_view/presentation/cubit/follow_list_cubit.dart';

/// Entry point — push this screen with [FollowListScreen.route].
class FollowListScreen extends StatelessWidget {
  final String userUuid;
  final String displayName;

  /// 0 = Fans (followers), 1 = Following
  final int initialTab;

  const FollowListScreen({
    super.key,
    required this.userUuid,
    required this.displayName,
    this.initialTab = 0,
  });

  /// Convenience factory for [Navigator.pushNamed] — just call this instead.
  static Route<void> route({
    required FollowListRemoteDataSource dataSource,
    required String userUuid,
    required String displayName,
    int initialTab = 0,
  }) {
    return MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) =>
            FollowListCubit(dataSource, userUuid: userUuid)..loadAll(),
        child: FollowListScreen(
          userUuid: userUuid,
          displayName: displayName,
          initialTab: initialTab,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FollowListView(
      userUuid: userUuid,
      displayName: displayName,
      initialTab: initialTab,
    );
  }
}

// ── Main view ─────────────────────────────────────────────────────────────────

class _FollowListView extends StatefulWidget {
  final String userUuid;
  final String displayName;
  final int initialTab;

  const _FollowListView({
    required this.userUuid,
    required this.displayName,
    required this.initialTab,
  });

  @override
  State<_FollowListView> createState() => _FollowListViewState();
}

class _FollowListViewState extends State<_FollowListView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
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
          child: Column(
            children: [
              // ── Custom AppBar ──────────────────────────────────────────
              _AppBar(displayName: widget.displayName),

              // ── TikTok-style tab indicator ─────────────────────────────
              _TabBar(controller: _tab),

              const SizedBox(height: 8),

              // ── Swipeable pages ────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _FollowersTab(userUuid: widget.userUuid),
                    _FollowingTab(userUuid: widget.userUuid),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final String displayName;
  const _AppBar({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              displayName,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowListCubit, FollowListState>(
      builder: (context, state) {
        final fanCount = state.followers.users.length;
        final followingCount = state.following.users.length;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(5),
          child: TabBar(
            controller: controller,
            indicator: BoxDecoration(
              color: const Color(0xFFFF7A00),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    state.followers.loading ? 'Fans' : 'Fans  $fanCount',
                    key: ValueKey(fanCount),
                  ),
                ),
              ),
              Tab(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    state.following.loading
                        ? 'Following'
                        : 'Following  $followingCount',
                    key: ValueKey(followingCount),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Followers tab ─────────────────────────────────────────────────────────────

class _FollowersTab extends StatefulWidget {
  final String userUuid;
  const _FollowersTab({required this.userUuid});

  @override
  State<_FollowersTab> createState() => _FollowersTabState();
}

class _FollowersTabState extends State<_FollowersTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent * 0.8) {
        context.read<FollowListCubit>().loadMoreFollowers();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<FollowListCubit, FollowListState>(
      builder: (context, state) {
        final tab = state.followers;
        if (tab.loading) return const _LoadingList();
        if (tab.error != null && tab.users.isEmpty) {
          return _ErrorState(
            message: tab.error!,
            onRetry: () => context.read<FollowListCubit>().loadFollowers(),
          );
        }
        if (tab.users.isEmpty) {
          return const _EmptyState(message: 'No fans yet');
        }
        return RefreshIndicator(
          color: const Color(0xFFFF7A00),
          backgroundColor: const Color(0xFF1B2153),
          onRefresh: () => context.read<FollowListCubit>().loadFollowers(),
          child: ListView.builder(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: tab.users.length + (tab.loadingMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= tab.users.length) {
                return const _LoadingMore();
              }
              return _UserTile(user: tab.users[i]);
            },
          ),
        );
      },
    );
  }
}

// ── Following tab ─────────────────────────────────────────────────────────────

class _FollowingTab extends StatefulWidget {
  final String userUuid;
  const _FollowingTab({required this.userUuid});

  @override
  State<_FollowingTab> createState() => _FollowingTabState();
}

class _FollowingTabState extends State<_FollowingTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent * 0.8) {
        context.read<FollowListCubit>().loadMoreFollowing();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<FollowListCubit, FollowListState>(
      builder: (context, state) {
        final tab = state.following;
        if (tab.loading) return const _LoadingList();
        if (tab.error != null && tab.users.isEmpty) {
          return _ErrorState(
            message: tab.error!,
            onRetry: () => context.read<FollowListCubit>().loadFollowing(),
          );
        }
        if (tab.users.isEmpty) {
          return const _EmptyState(message: 'Not following anyone yet');
        }
        return RefreshIndicator(
          color: const Color(0xFFFF7A00),
          backgroundColor: const Color(0xFF1B2153),
          onRefresh: () => context.read<FollowListCubit>().loadFollowing(),
          child: ListView.builder(
            controller: _scroll,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: tab.users.length + (tab.loadingMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= tab.users.length) {
                return const _LoadingMore();
              }
              return _UserTile(user: tab.users[i]);
            },
          ),
        );
      },
    );
  }
}

// ── User tile ─────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final FollowListUser user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(
            context,
            RouteNames.profileView,
            arguments: {'userUuid': user.uuid},
          ),
          splashColor: Colors.white.withOpacity(0.05),
          highlightColor: Colors.white.withOpacity(0.03),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                // ── Avatar ───────────────────────────────────────────────
                _Avatar(url: user.avatarUrl, uuid: user.uuid),

                const SizedBox(width: 14),

                // ── Name / slug ──────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullname.isNotEmpty
                            ? user.fullname
                            : '@${user.userSlug}',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user.userSlug.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@${user.userSlug}',
                          style: AppTextStyles.small.copyWith(
                            color: Colors.white54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // ── Follow button ────────────────────────────────────────
                _FollowButton(user: user),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String url;
  final String uuid;
  const _Avatar({required this.url, required this.uuid});

  bool get _valid {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        RouteNames.profileView,
        arguments: {'userUuid': uuid},
      ),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A00), Color(0xFFFF4D00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: _valid
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: 48,
                  height: 48,
                  placeholder: (_, __) => Container(
                    color: Colors.white10,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF1B2153),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white70,
                      size: 24,
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFF1B2153),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Follow button ─────────────────────────────────────────────────────────────

class _FollowButton extends StatelessWidget {
  final FollowListUser user;
  const _FollowButton({required this.user});

  @override
  Widget build(BuildContext context) {
    final following = user.isFollowing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: SizedBox(
        height: 34,
        child: following
            ? OutlinedButton(
                onPressed: () =>
                    context.read<FollowListCubit>().toggleFollow(user.uuid),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.2,
                  ),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Following',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              )
            : ElevatedButton(
                onPressed: () =>
                    context.read<FollowListCubit>().toggleFollow(user.uuid),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Follow',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
      ),
    );
  }
}

// ── Loading / Empty / Error states ───────────────────────────────────────────

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      itemCount: 8,
      itemBuilder: (_, __) => const _TileSkeleton(),
    );
  }
}

class _TileSkeleton extends StatefulWidget {
  const _TileSkeleton();
  @override
  State<_TileSkeleton> createState() => _TileSkeletonState();
}

class _TileSkeletonState extends State<_TileSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final opacity = 0.04 + _ctrl.value * 0.06;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(opacity + 0.04),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 13,
                        width: 130,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(opacity + 0.04),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(opacity),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 34,
                  width: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(opacity + 0.04),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoadingMore extends StatelessWidget {
  const _LoadingMore();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFF7A00),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              color: Colors.white38,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Color(0xFFFF7A00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
