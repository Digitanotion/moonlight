// lib/features/profile_setup/presentation/pages/my_profile_screen.dart

import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/auth/data/models/user_model.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/pages/my_clubs_tab.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:moonlight/features/post_view/domain/entities/user.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_page_cubit.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:moonlight/features/profile_view/presentation/pages/follow_list_screen.dart';
import 'package:moonlight/features/profile_view/data/datasources/follow_list_remote_datasource.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isShowingProgress = false;
  final Map<int, Uint8List?> _videoThumbCache = {};
  String? _currentUserUuid;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserUuid();
    // Load profile data including posts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfilePageCubit>().load();
    });
  }

  Future<void> _loadCurrentUserUuid() async {
    try {
      final authLocalDataSource = sl<AuthLocalDataSource>();
      final uuid = await authLocalDataSource.getCurrentUserUuid();
      setState(() {
        _currentUserUuid = uuid;
      });
    } catch (e) {
      print('Error loading user UUID: $e');
    }
  }

  void _showProgress() {
    if (_isShowingProgress) return;
    _isShowingProgress = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _hideProgress() {
    if (!_isShowingProgress) return;
    _isShowingProgress = false;
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _confirmLogout() async {
    HapticFeedback.selectionClick();
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to log out? You will need to sign in again to access your account.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(c).pop(false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.vibrate();
              Navigator.of(c).pop(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF6F61),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (res == true) {
      context.read<AuthBloc>().add(LogoutRequested());
    }
  }

  void _onAuthStateChanged(BuildContext ctx, AuthState state) {
    if (state is AuthLoading) {
      _showProgress();
    } else {
      _hideProgress();
    }

    if (state is AuthUnauthenticated) {
      Navigator.pushNamedAndRemoveUntil(
        ctx,
        RouteNames.login,
        (route) => false,
      );
    }

    if (state is AuthFailure) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text(state.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    final gradient = const LinearGradient(
      colors: [Color(0xFF0C0F52), Color(0xFF0A0A0F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return MultiBlocListener(
      listeners: [
        BlocListener<ProfilePageCubit, ProfilePageState>(
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error!)));
            }
          },
        ),
        BlocListener<AuthBloc, AuthState>(listener: _onAuthStateChanged),
      ],
      child: BlocBuilder<ProfilePageCubit, ProfilePageState>(
        builder: (context, state) {
          final user = state.user;
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(gradient: gradient),
              child: SafeArea(
                child: RefreshIndicator(
                  color: orange,
                  onRefresh: () async {
                    await context.read<ProfilePageCubit>().load(haptic: true);
                  },
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Spacer(),
                              Text(
                                'My Profile',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),

                      // Header card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Column(
                            children: [
                              // avatar
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.08),
                                  image: (user?.avatarUrl != null)
                                      ? DecorationImage(
                                          image: NetworkImage(user!.avatarUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: (user?.avatarUrl == null)
                                    ? const Icon(
                                        Icons.person_outline,
                                        color: Colors.white70,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '@${user?.userSlug ?? 'username'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.fullname ?? '',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _vipChip(user?.roleLabel ?? "Nominal Member"),
                              const SizedBox(height: 12),
                              _bioLines(user?.bio),
                              const SizedBox(height: 16),

                              // Dashboard button
                              SizedBox(
                                width: 160,
                                child: ElevatedButton(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _openDashboardSheet();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: orange,
                                    foregroundColor: AppColors.textWhite,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text(
                                    'Dashboard',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Stats Card with Fans & Following
                              _statsCard(user, context),
                            ],
                          ),
                        ),
                      ),

                      // Segmented tabs
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _tabsBar(
                            selected: state.tab,
                            onTap: (t) =>
                                context.read<ProfilePageCubit>().switchTab(t),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      // Content
                      if (state.loading && user == null)
                        const SliverToBoxAdapter(child: _ShimmerList())
                      else
                        switch (state.tab) {
                          ProfileTab.posts => SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: _postsGrid(state.posts),
                          ),
                          ProfileTab.clubs => SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: RepositoryProvider<ClubsRepository>.value(
                                value: sl<ClubsRepository>(),
                                child: BlocProvider(
                                  create: (_) => sl<MyClubsCubit>()..load(),
                                  child: const MyClubsTab(),
                                ),
                              ),
                            ),
                          ),
                        },

                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
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

  // Stats Card with clickable Fans and Following
  Widget _statsCard(UserModel? user, BuildContext context) {
    if (user == null) return const SizedBox.shrink();

    // You need to have followersCount and followingCount in your UserModel
    // If not, you might need to fetch them from the API or use placeholders
    final followersCount = user.followersCount ?? 0;
    final followingCount = user.followingCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2153), Color(0xFF0F1432)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Fans - opens followers tab
          Expanded(
            child: _StatItem(
              label: 'Fans',
              value: '$followersCount',
              onTap: () => _openFollowList(context, initialTab: 0),
            ),
          ),
          // Following - opens following tab
          Expanded(
            child: _StatItem(
              label: 'Following',
              value: '$followingCount',
              onTap: () => _openFollowList(context, initialTab: 1),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to open follow list
  void _openFollowList(BuildContext context, {required int initialTab}) {
    final user = context.read<ProfilePageCubit>().state.user;
    if (user == null || user.uuid == null) {
      print('Cannot open follow list: user or UUID is null');
      return;
    }

    final ds = GetIt.I<FollowListRemoteDataSource>();
    Navigator.push(
      context,
      FollowListScreen.route(
        dataSource: ds,
        userUuid: user.uuid!,
        displayName: user.fullname ?? user.userSlug ?? 'User',
        initialTab: initialTab,
      ),
    );
  }

  Widget _vipChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF1E2035),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.workspace_premium, color: const Color(0xFFFFD54F), size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _bioLines(String? bio) {
    final lines = (bio == null || bio.trim().isEmpty)
        ? []
        : bio.split('|').map((e) => e.trim()).toList();

    return Column(
      children: lines
          .map(
            (l) => Text(
              l,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _tabsBar({
    required ProfileTab selected,
    required ValueChanged<ProfileTab> onTap,
  }) {
    Widget tab(String label, ProfileTab t) {
      final isSel = selected == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => onTap(t),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSel
                  ? AppColors.secondary.withOpacity(0.7)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSel ? const Color(0xFFFF7A00) : Colors.white24,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(isSel ? 1 : .7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('Posts', ProfileTab.posts),
        const SizedBox(width: 10),
        tab('Clubs', ProfileTab.clubs),
      ],
    );
  }

  SliverGrid _postsGrid(List<Post> posts) {
    if (posts.isEmpty) {
      return SliverGrid(
        delegate: SliverChildListDelegate([
          Container(
            height: 200,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 48,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Posts Yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first post to share with others',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ]),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2,
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      delegate: SliverChildBuilderDelegate((context, idx) {
        final Post p = posts[idx];
        final isVideo = p.isVideo;
        final mediaUrl = p.mediaUrl;
        final thumbUrl = p.thumbUrl;

        return GestureDetector(
          onTap: () {
            try {
              Navigator.pushNamed(
                context,
                RouteNames.postView,
                arguments: {'postId': p.id, 'isOwner': true},
              );
            } catch (_) {}
          },
          child: Hero(
            tag: 'post_${p.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isVideo
                  ? FutureBuilder<Uint8List?>(
                      future: _getVideoThumbnailForPost(idx, p),
                      builder: (c, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return Container(color: Colors.white12);
                        }
                        final bytes = snap.data;
                        if (bytes != null) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(bytes, fit: BoxFit.cover),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  size: 40,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          );
                        }
                        final fallback =
                            (thumbUrl != null && thumbUrl.isNotEmpty)
                            ? thumbUrl
                            : mediaUrl;
                        return CachedNetworkImage(
                          imageUrl: fallback,
                          fit: BoxFit.cover,
                          placeholder: (c, _) =>
                              Container(color: Colors.white12),
                          errorWidget: (c, _, __) =>
                              Container(color: Colors.white12),
                        );
                      },
                    )
                  : CachedNetworkImage(
                      imageUrl: p.mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (c, _) => Container(color: Colors.white12),
                      errorWidget: (c, _, __) =>
                          Container(color: Colors.white12),
                    ),
            ),
          ),
        );
      }, childCount: posts.length),
    );
  }

  Future<Uint8List?> _getVideoThumbnailForPost(int idx, Post p) async {
    final key = idx;
    if (_videoThumbCache.containsKey(key)) return _videoThumbCache[key];

    if (p.thumbUrl != null && p.thumbUrl!.isNotEmpty) {
      _videoThumbCache[key] = null;
      return null;
    }

    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: p.mediaUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 1024,
        quality: 75,
      );
      _videoThumbCache[key] = bytes;
      return bytes;
    } catch (_) {
      _videoThumbCache[key] = null;
      return null;
    }
  }

  void _openDashboardSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF07121F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dashboard',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: const Text(
                    'Edit Profile',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, RouteNames.editProfile);
                  },
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Wallet & Earnings',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, RouteNames.wallet);
                  },
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Account Settings',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, RouteNames.accountSettings);
                  },
                ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFFF6F61),
                  ),
                  title: const Text(
                    'Log out',
                    style: TextStyle(color: Color(0xFFFF6F61)),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _confirmLogout();
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

// StatItem widget for clickable stats
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _StatItem({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
        if (onTap != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 24,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      splashColor: Colors.white.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: content,
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: List.generate(3, (i) => _shimmerItem()).toList()),
    );
  }

  Widget _shimmerItem() => Container(
    height: 160,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white24),
    ),
  );
}
