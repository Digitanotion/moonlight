import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/pages/my_clubs_tab.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:moonlight/features/post_view/domain/entities/user.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_page_cubit.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// new import
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
// if you have one

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isShowingProgress = false;

  // cache generated thumbnails for videos to avoid regenerating on scroll
  final Map<int, Uint8List?> _videoThumbCache = {};

  @override
  void initState() {
    super.initState();
    // context.read<ProfilePageCubit>().load();
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
      // dispatch logout
      context.read<AuthBloc>().add(LogoutRequested());
    }
  }

  void _onAuthStateChanged(BuildContext ctx, AuthState state) {
    if (state is AuthLoading) {
      _showProgress();
    } else {
      // hide progress for any non-loading state
      _hideProgress();
    }

    if (state is AuthUnauthenticated) {
      // successful logout -> route to login/register and clear stack
      Navigator.pushNamedAndRemoveUntil(
        ctx,
        RouteNames
            .login, // replace with your login route name, e.g. RouteNames.login
        (route) => false,
      );
    }

    if (state is AuthFailure) {
      // show error
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

    // MultiBlocListener so we keep listening to ProfilePageCubit (existing)
    // and also to AuthBloc for logout results.
    return MultiBlocListener(
      listeners: [
        // keep your profile page listener (converted from BlocConsumer listener piece)
        BlocListener<ProfilePageCubit, ProfilePageState>(
          listener: (context, state) {
            if (state.error != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.error!)));
            }
          },
        ),
        // Auth listener for logout flow
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
                  onRefresh: () =>
                      context.read<ProfilePageCubit>().load(haptic: true),
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
                              // settings icon removed as requested
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

                              // Dashboard button (replaces Edit Profile)
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

                              // Stats card (kept commented as before)
                              // _statsCard(...),
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
                          // temporarily disabled
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
                          // ProfileTab.livestreams => SliverToBoxAdapter(
                          //   child: Padding(
                          //     padding: const EdgeInsets.symmetric(
                          //       horizontal: 16,
                          //     ),
                          //     child: _placeholderNotAvailable(),
                          //   ),
                          // ),
                        },

                      // Previously there was an actions panel here (duplicate of dashboard actions).
                      // Per request, removed the bottom panel that contained the Edit Profile duplicate.
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

  Widget _placeholderNotAvailable() {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Not available at the moment',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _iconButton(BuildContext ctx, IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        width: 36,
        height: 36,
        child: Icon(icon, color: Colors.white, size: 20),
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
        Icon(Icons.workspace_premium, color: Color(0xFFFFD54F), size: 16),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
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
        // const SizedBox(width: 10),
        // tab('Livestreams', ProfileTab.livestreams),
      ],
    );
  }

  // Posts grid that handles images and videos
  SliverGrid _postsGrid(List<dynamic> posts) {
    final List<Post> typed = posts
        .map<Post?>((p) {
          if (p == null) return null;
          if (p is Post) return p;
          if (p is Map<String, dynamic>) {
            try {
              final authorMap = p['author'] is Map
                  ? (p['author'] as Map).cast<String, dynamic>()
                  : <String, dynamic>{};
              final au = AppUser(
                id: (authorMap['id'] ?? authorMap['uuid'] ?? '0').toString(),
                name: (authorMap['name'] ?? authorMap['fullName'] ?? '')
                    .toString(),
                avatarUrl:
                    (authorMap['avatarUrl'] ?? authorMap['avatar_url'] ?? '')
                        .toString(),
                countryFlagEmoji:
                    (authorMap['countryFlagEmoji'] ??
                            authorMap['country_flag_emoji'] ??
                            '')
                        .toString(),
                roleLabel:
                    (authorMap['roleLabel'] ?? authorMap['role_label'] ?? '')
                        .toString(),
                roleColor:
                    (authorMap['roleColor'] ?? authorMap['role_color'] ?? '')
                        .toString(),
              );

              final id = (p['uuid'] ?? p['id'] ?? p['post_id'] ?? '')
                  .toString();
              final mediaUrl =
                  (p['mediaUrl'] ?? p['media_url'] ?? p['url'] ?? '')
                      .toString();
              final thumb =
                  (p['thumbUrl'] ??
                          p['thumb'] ??
                          p['thumbnail'] ??
                          p['thumb_url'])
                      ?.toString();
              final mediaType =
                  (p['mediaType'] ??
                          p['media_type'] ??
                          p['mime'] ??
                          p['mimetype'])
                      ?.toString();
              final caption = (p['caption'] ?? '').toString();
              final tags = (p['tags'] is List)
                  ? (p['tags'] as List).map((e) => '$e').toList()
                  : <String>[];
              final created =
                  DateTime.tryParse(
                    (p['createdAt'] ?? p['created_at'] ?? '').toString(),
                  ) ??
                  DateTime.now();
              final likes = (p['likes'] is num)
                  ? (p['likes'] as num).toInt()
                  : int.tryParse((p['likes'] ?? '0').toString()) ?? 0;
              final comments =
                  (p['commentsCount'] ?? p['comments_count'] ?? 0) is num
                  ? ((p['commentsCount'] ?? p['comments_count'] ?? 0) as num)
                        .toInt()
                  : int.tryParse(
                          (p['commentsCount'] ?? p['comments_count'] ?? '0')
                              .toString(),
                        ) ??
                        0;
              final shares = (p['shares'] is num)
                  ? (p['shares'] as num).toInt()
                  : int.tryParse((p['shares'] ?? '0').toString()) ?? 0;
              final isLiked = (p['isLiked'] == true) || (p['is_liked'] == true);
              final views = (p['views'] is num)
                  ? (p['views'] as num).toInt()
                  : int.tryParse((p['views'] ?? '0').toString()) ?? 0;

              return Post(
                id: id.isNotEmpty ? id : mediaUrl.hashCode.toString(),
                author: au,
                mediaUrl: mediaUrl,
                thumbUrl: thumb,
                mediaType: mediaType,
                caption: caption,
                tags: tags,
                createdAt: created,
                likes: likes,
                commentsCount: comments,
                shares: shares,
                isLiked: isLiked,
                views: views,
              );
            } catch (_) {
              return null;
            }
          }

          try {
            final dyn = p as dynamic;
            final id = (dyn.id ?? dyn.uuid ?? '').toString();
            final url = (dyn.mediaUrl ?? dyn.url ?? '').toString();
            final mt = (dyn.mediaType ?? dyn.mime ?? '').toString();
            return Post(
              id: id.isNotEmpty ? id : url.hashCode.toString(),
              author: AppUser(
                id: '0',
                name: '',
                avatarUrl: '',
                countryFlagEmoji: '',
                roleLabel: '',
                roleColor: '',
              ),
              mediaUrl: url,
              mediaType: mt.isNotEmpty ? mt : null,
              caption: (dyn.caption ?? '').toString(),
              tags: <String>[],
              createdAt: DateTime.now(),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<Post>()
        .toList();

    // CHANGED: Check if posts are empty and return a SliverToBoxAdapter with "No Posts Yet"
    if (typed.isEmpty) {
      return SliverGrid(
        delegate: SliverChildListDelegate([
          Container(
            height: 200, // Set a reasonable height
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
          crossAxisCount: 1, // Single column for the message
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2, // Wider aspect ratio for the message
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
        final Post p = typed[idx];
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
      }, childCount: typed.length),
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

  Future<Uint8List?> _getVideoThumbnail(int index, String videoUrl) async {
    if (_videoThumbCache.containsKey(index)) return _videoThumbCache[index];
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 1024,
        quality: 75,
      );
      _videoThumbCache[index] = bytes;
      return bytes;
    } catch (_) {
      _videoThumbCache[index] = null;
      return null;
    }
  }

  String _extractMediaUrl(dynamic p) {
    try {
      if (p == null) return '';
      if (p is String)
        return p; // earlier implementations may have been a list of urls
      if (p is Map) {
        // common possible keys
        return (p['mediaUrl'] ??
                p['media_url'] ??
                p['url'] ??
                p['thumbnail'] ??
                '')
            .toString();
      }
      // fallback to using a mediaUrl property (Post entity)
      final media = (p as dynamic).mediaUrl;
      return media?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  bool _isVideoPost(dynamic p) {
    try {
      if (p == null) return false;
      if (p is Map) {
        final t = (p['type'] ?? p['media_type'] ?? p['mime'] ?? p['mimetype'])
            ?.toString()
            .toLowerCase();
        if (t == null) return false;
        return t.contains('video') || t.contains('mp4') || t.contains('mov');
      }
      final mim = (p as dynamic).mediaType;
      if (mim != null) return mim.toString().toLowerCase().contains('video');
      final url = _extractMediaUrl(p);
      return url.endsWith('.mp4') ||
          url.endsWith('.mov') ||
          url.contains('video');
    } catch (_) {
      return false;
    }
  }

  String _extractPostId(dynamic p) {
    try {
      if (p == null) return '0';
      if (p is Map)
        return (p['uuid'] ?? p['id'] ?? p['post_id'] ?? '${p.hashCode}')
            .toString();
      return (p as dynamic).id?.toString() ?? '0';
    } catch (_) {
      return '0';
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

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    // Minimal placeholder without external packages
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: List.generate(3, (i) => _item()).toList()),
    );
  }

  Widget _item() => Container(
    height: 160,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white24),
    ),
  );
}
