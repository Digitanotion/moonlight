import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonlight/features/chat/presentation/pages/cubit/chat_cubit.dart';
import 'package:moonlight/features/profile_view/presentation/cubit/profile_cubit.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ProfileViewPage extends StatefulWidget {
  const ProfileViewPage({super.key});

  @override
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  int _tabIndex = 0;
  String? _userUuid;

  final _scroll = ScrollController();
  // Add a GlobalKey for the navigator
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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

  void _showBlockConfirmationDialog(BuildContext context) {
    final cubit = context.read<ProfileCubit>();
    final user = cubit.state.user;
    if (user == null) return;

    String? selectedReason;
    final reasons = [
      'Harassment or bullying',
      'Inappropriate content',
      'Spam',
      'Impersonation',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1B2153),
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Block User',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to block ${user.fullName}?',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select a reason (optional):',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...reasons.map((reason) {
                  return RadioListTile<String>(
                    title: Text(
                      reason,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) {
                      setState(() => selectedReason = value);
                    },
                    activeColor: const Color(0xFFFF7A00),
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
                const SizedBox(height: 8),
                TextFormField(
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Other reason...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      selectedReason = value;
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _performBlock(
                    context,
                    cubit,
                    user.uuid,
                    reason: selectedReason,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Block User'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _performBlock(
    BuildContext context,
    ProfileCubit cubit,
    String userUuid, {
    String? reason,
  }) async {
    // Get references BEFORE any async operation
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show loading dialog
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.orange),
                SizedBox(height: 16),
                Text('Blocking user...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );

    // Track results
    String? resultMessage;
    Color? snackbarColor;
    bool shouldNavigateBack = false;

    try {
      await cubit.blockUser(reason: reason);
      resultMessage = 'User blocked successfully';
      snackbarColor = Colors.green;
      shouldNavigateBack = false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        resultMessage = 'User is already blocked';
        snackbarColor = Colors.orange;
        shouldNavigateBack = false;
      } else {
        resultMessage = 'Failed to block user: ${e.message}';
        snackbarColor = Colors.red;
      }
    } catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('already blocked')) {
        resultMessage = 'User is already blocked';
        snackbarColor = Colors.orange;
        shouldNavigateBack = false;
      } else {
        resultMessage = 'Failed to block user: $errorMessage';
        snackbarColor = Colors.red;
      }
    }

    // Close the loading dialog
    navigator.pop();

    // Wait for dialog to close completely
    await dialogFuture;

    // Small delay to ensure everything is settled
    await Future.delayed(Duration(milliseconds: 50));

    // Show snackbar using the stored scaffoldMessenger
    if (resultMessage != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(resultMessage!),
          backgroundColor: snackbarColor,
          duration: Duration(seconds: 2),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {
              scaffoldMessenger.hideCurrentSnackBar();
            },
          ),
        ),
      );

      // Navigate back if needed
      if (shouldNavigateBack) {
        await Future.delayed(Duration(milliseconds: 1500));
        if (mounted) {
          navigator.pop();
        }
      }
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
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'block') {
                            _showBlockConfirmationDialog(context);
                          } else if (value == 'report') {
                            // Handle report if needed
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'block',
                            child: Row(
                              children: [
                                Icon(Icons.block, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Block User'),
                              ],
                            ),
                          ),
                          // const PopupMenuItem<String>(
                          //   value: 'report',
                          //   child: Row(
                          //     children: [
                          //       Icon(
                          //         Icons.report,
                          //         color: Colors.orange,
                          //         size: 20,
                          //       ),
                          //       SizedBox(width: 8),
                          //       Text('Report'),
                          //     ],
                          //   ),
                          // ),
                        ],
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
                          // REPLACE the old avatar Container with this widget
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
                            child: _ProfileAvatar(
                              avatarUrl: user?.avatarUrl,
                              radius: 33,
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
                          _BadgePill(
                            label: user?.roleLabel ?? "Nominal Member",
                          ),
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
                                child: BlocBuilder<ProfileCubit, ProfileState>(
                                  builder: (context, s) {
                                    final isFollowing =
                                        s.user?.isFollowing == true;

                                    return SizedBox(
                                      height: 46,
                                      child: ElevatedButton(
                                        onPressed: () => context
                                            .read<ProfileCubit>()
                                            .toggleFollow(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isFollowing
                                              ? Colors.white10
                                              : const Color(0xFFFF7A00),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              26,
                                            ),
                                            side: isFollowing
                                                ? BorderSide(
                                                    color: Colors.white
                                                        .withOpacity(0.25),
                                                  )
                                                : BorderSide.none,
                                          ),
                                          elevation: 0,
                                        ),
                                        child: Text(
                                          isFollowing ? 'Following' : 'Follow',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: BlocBuilder<ProfileCubit, ProfileState>(
                                  builder: (context, s) {
                                    final targetUserUuid = s.user?.uuid ?? '';

                                    return _OutlineButton(
                                      text: 'Message',
                                      targetUserUuid:
                                          targetUserUuid, // Pass the UUID
                                      onPressed: () => _startConversation(
                                        context,
                                        targetUserUuid,
                                      ),
                                    );
                                  },
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

  void _startConversation(BuildContext context, String targetUserUuid) async {
    if (targetUserUuid.isEmpty) {
      TopSnack.error(context, 'Unable to start conversation');

      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Starting conversation...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );

    // Declare variables at the top level so they're accessible in all scopes
    StreamSubscription? subscription;
    ChatCubit? chatCubit;

    try {
      // Create a new ChatCubit instance directly
      final chatRepository = GetIt.I<ChatRepository>();
      chatCubit = ChatCubit(chatRepository);

      // Listen for the conversation creation
      subscription = chatCubit.stream.listen(
        (state) {
          if (state is ChatDirectConversationStarted) {
            // Close loading dialog
            Navigator.pop(context);

            // Navigate to chat screen with the real conversation
            Navigator.pushNamed(
              context,
              RouteNames.chat,
              arguments: {'conversation': state.conversation, 'isClub': false},
            );

            // Clean up
            subscription?.cancel();
            chatCubit?.close();
          } else if (state is ChatError) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
            subscription?.cancel();
            chatCubit?.close();
          }
        },
        onError: (error) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
            ),
          );
          subscription?.cancel();
          chatCubit?.close();
        },
      );

      // Start direct conversation
      chatCubit.startDirectConversation(targetUserUuid);
    } catch (e) {
      // Clean up in case of exception
      subscription?.cancel();
      chatCubit?.close();

      // Close loading dialog
      Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start conversation: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;

  const _ProfileAvatar({this.avatarUrl, this.radius = 33, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasUrl = (avatarUrl != null && avatarUrl!.trim().isNotEmpty);

    // size of outer widget (diameter)
    final size = radius * 2;

    // circle background color used when no avatar is present
    const placeholderBg = Colors.black12;

    if (!hasUrl) {
      // No URL at all — show placeholder icon immediately
      return CircleAvatar(
        radius: radius,
        backgroundColor: placeholderBg,
        child: Icon(Icons.person_outline, color: Colors.white70, size: radius),
      );
    }

    // When we have a URL, use CachedNetworkImage so we can show an error widget
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          fit: BoxFit.cover,
          width: size,
          height: size,
          // When the image successfully loads, this builder uses it as the avatar.
          imageBuilder: (context, imageProvider) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
          // while loading show a subtle background
          placeholder: (context, url) => Container(
            color: placeholderBg,
            alignment: Alignment.center,
            child: Icon(
              Icons.person_outline,
              color: Colors.white54,
              size: radius * 0.9,
            ),
          ),
          // on error (e.g., network/auth failure) show the icon placeholder
          errorWidget: (context, url, error) => Container(
            color: placeholderBg,
            alignment: Alignment.center,
            child: Icon(
              Icons.person_outline,
              color: Colors.white70,
              size: radius,
            ),
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
  const _OutlineButton({
    required this.text,
    required this.onPressed,
    required this.targetUserUuid, // Add this parameter
  });

  final String text;
  final VoidCallback onPressed;
  final String targetUserUuid; // Add this

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
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: Colors.white,
            child: Icon(Icons.verified, size: 14, color: Color(0xFF8B4C00)),
          ),
          SizedBox(width: 8),
          Text(
            label,
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
              child: PostTile(post: p),
            ),
          ),
        );
      }, childCount: posts.length),
    );
  }
}

class PostTile extends StatefulWidget {
  const PostTile({required this.post, Key? key}) : super(key: key);
  final dynamic post; // expect Post domain entity

  @override
  State<PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<PostTile> {
  // simple in-memory cache across all PostTile instances
  static final Map<String, Uint8List?> _thumbCache = {};
  Uint8List? _thumb;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ensureThumb();
  }

  Future<void> _ensureThumb() async {
    final p = widget.post;
    // resolve id & media url defensively
    final id = (p is dynamic)
        ? (p.id?.toString() ??
              p.uuid?.toString() ??
              p.mediaUrl.hashCode.toString())
        : p.toString();
    final mediaUrl = (p is dynamic)
        ? (p.mediaUrl?.toString() ?? '')
        : p.toString();
    final thumbUrl = (p is dynamic) ? (p.thumbUrl?.toString() ?? '') : '';

    // if not a video, nothing to generate
    final isVideo = (p is dynamic) ? (p.isVideo == true) : false;
    if (!isVideo) return;

    // if backend provided a thumbnail URL, don't generate — UI will load network image
    if (thumbUrl.isNotEmpty) return;

    // if already cached, use it
    if (_thumbCache.containsKey(id)) {
      setState(() {
        _thumb = _thumbCache[id];
      });
      return;
    }

    // generate thumbnail asynchronously
    setState(() => _loading = true);
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: mediaUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 1024,
        quality: 75,
      );
      _thumbCache[id] = bytes;
      if (mounted) {
        setState(() {
          _thumb = bytes;
        });
      }
    } catch (_) {
      _thumbCache[id] = null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final isVideo = (p is dynamic) ? (p.isVideo == true) : false;
    final mediaUrl = (p is dynamic)
        ? (p.mediaUrl?.toString() ?? '')
        : p.toString();
    final thumbUrl = (p is dynamic) ? (p.thumbUrl?.toString() ?? '') : '';

    if (isVideo) {
      // if we have generated bytes, show them; otherwise use provided thumbUrl or fallback to mediaUrl
      if (_thumb != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(_thumb!, fit: BoxFit.cover),
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 40,
                color: Colors.white70,
              ),
            ),
          ],
        );
      } else {
        final fallback = (thumbUrl.isNotEmpty) ? thumbUrl : mediaUrl;
        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: fallback,
              fit: BoxFit.cover,
              placeholder: (c, _) => Container(color: Colors.white12),
              errorWidget: (c, _, __) => Container(color: Colors.white12),
            ),
            if (_loading)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
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
    }

    // non-video: regular network image
    return CachedNetworkImage(
      imageUrl: mediaUrl,
      fit: BoxFit.cover,
      placeholder: (c, _) => Container(color: Colors.white12),
      errorWidget: (c, _, __) => Container(color: Colors.white12),
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
