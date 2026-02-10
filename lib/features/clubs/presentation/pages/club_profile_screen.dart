import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/icon_data.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/clubs/presentation/cubit/discover_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/pages/club_income_details_screen.dart';
import 'package:moonlight/features/clubs/domain/entities/club_profile.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_profile_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_profile_state.dart';
import 'package:moonlight/features/clubs/presentation/pages/support_club_page.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClubProfileScreen extends StatefulWidget {
  const ClubProfileScreen({super.key});

  @override
  State<ClubProfileScreen> createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _showMessageGuide = false;
  final GlobalKey _messageButtonKey = GlobalKey();
  bool _isLayoutComplete = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkShouldShowGuide();
      setState(() {
        _isLayoutComplete = true;
      });
    });
  }

  Future<void> _checkShouldShowGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGuide = prefs.getBool('club_message_guide_seen') ?? false;

    if (!hasSeenGuide) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _showMessageGuide = true;
        });
      }
    }
  }

  Future<void> _dismissGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('club_message_guide_seen', true);
    if (mounted) {
      setState(() {
        _showMessageGuide = false;
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      body: BlocConsumer<ClubProfileCubit, ClubProfileState>(
        listener: (context, state) {
          // Handle errors
          if (state.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              TopSnack.error(context, state.error!);
              context.read<ClubProfileCubit>().clearMessages();
            });
          }

          // Handle success messages
          if (state.success != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              TopSnack.success(context, state.success!);
              context.read<ClubProfileCubit>().clearMessages();
            });
          }
        },
        builder: (context, state) {
          if (state.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final club = state.profile;
          if (club == null) {
            return const Center(
              child: Text(
                'Unable to load club',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return Stack(
            children: [
              _CoverImage(
                url: club.coverImageUrl,
                name: club.name,
                slug: club.slug,
              ),

              SafeArea(
                child: Column(
                  children: [
                    _TopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 220, 16, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeaderMeta(
                              club: club,
                              messageButtonKey: _messageButtonKey,
                            ),
                            const SizedBox(height: 30),
                            _DescriptionCard(club.description),
                            const SizedBox(height: 25),
                            _IncomeCard(club: club, clubUuid: club.uuid),
                            const SizedBox(height: 35),
                            _TopMembers(members: club.membersYouKnow),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Modern floating guide for messaging - only show after layout is complete
              if (_showMessageGuide && club.isMember && _isLayoutComplete)
                _MessageGuideOverlay(
                  messageButtonKey: _messageButtonKey,
                  clubName: club.name,
                  onDismiss: _dismissGuide,
                ),
            ],
          );
        },
      ),
    );
  }
}

/* ─────────────────── MESSAGE GUIDE OVERLAY ─────────────────── */

class _MessageGuideOverlay extends StatefulWidget {
  final GlobalKey messageButtonKey;
  final String clubName;
  final VoidCallback onDismiss;

  const _MessageGuideOverlay({
    required this.messageButtonKey,
    required this.clubName,
    required this.onDismiss,
  });

  @override
  State<_MessageGuideOverlay> createState() => __MessageGuideOverlayState();
}

class __MessageGuideOverlayState extends State<_MessageGuideOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  Offset? _buttonPosition;
  Size? _buttonSize;

  @override
  void initState() {
    super.initState();

    // Wait for the next frame to ensure layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getButtonPosition();
    });

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _getButtonPosition() {
    final context = widget.messageButtonKey.currentContext;
    if (context != null) {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        setState(() {
          _buttonPosition = renderBox.localToGlobal(Offset.zero);
          _buttonSize = renderBox.size;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If we don't have the button position yet, show nothing
    if (_buttonPosition == null || _buttonSize == null) {
      return const SizedBox.shrink();
    }

    // Calculate guide position
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double guideLeft = _buttonPosition!.dx + _buttonSize!.width / 2 - 150;
    guideLeft = guideLeft.clamp(16, screenWidth - 316);

    double guideTop = _buttonPosition!.dy - 140;
    guideTop = guideTop.clamp(100, screenHeight - 220);

    return Positioned.fill(
      child: Stack(
        children: [
          // Dimmed overlay with tap to dismiss
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),

          // Guide bubble
          Positioned(
            left: guideLeft,
            top: guideTop,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: _GuideBubble(
                  clubName: widget.clubName,
                  onDismiss: widget.onDismiss,
                  onNavigateToMessages: () {
                    widget.onDismiss();
                    Navigator.pushNamed(context, RouteNames.conversations);
                  },
                ),
              ),
            ),
          ),

          // Highlight ring around message button
          Positioned(
            left: _buttonPosition!.dx - 8,
            top: _buttonPosition!.dy - 8,
            child: Container(
              width: _buttonSize!.width + 16,
              height: _buttonSize!.height + 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blue.withOpacity(0.8),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideBubble extends StatelessWidget {
  final String clubName;
  final VoidCallback onDismiss;
  final VoidCallback onNavigateToMessages;

  const _GuideBubble({
    required this.clubName,
    required this.onDismiss,
    required this.onNavigateToMessages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F6BED), Color(0xFF8458FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.spa, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome to the club! 🎉',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You\'ve joined "$clubName"',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.blue.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready to chat with everyone?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Tap the ',
                        style: TextStyle(color: Colors.white70),
                      ),
                      WidgetSpan(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.message,
                            color: Colors.blue,
                            size: 12,
                          ),
                        ),
                      ),
                      const TextSpan(
                        text:
                            ' button above to go to Messages, then select "Clubs" to find your club.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onNavigateToMessages,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.message, size: 16),
                        SizedBox(width: 8),
                        Text('Go to Messages'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────── TOP BAR ─────────────────── */

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          Text(
            'Club Profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          SizedBox(width: 20),
        ],
      ),
    );
  }
}

/* ─────────────────── COVER ─────────────────── */

class _CoverImage extends StatelessWidget {
  final String? url;
  final String name;
  final String slug;

  const _CoverImage({this.url, required this.name, required this.slug});

  bool get _hasValidUrl =>
      url != null && url!.trim().isNotEmpty && url!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    final icon = clubPlaceholderIcon(name: name, slug: slug);

    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF060616), Color(0xFF1B1B3A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 88,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          if (_hasValidUrl)
            Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),

          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black87],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────── HEADER META ─────────────────── */

class _HeaderMeta extends StatelessWidget {
  final dynamic club;
  final GlobalKey messageButtonKey;

  const _HeaderMeta({required this.club, required this.messageButtonKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Avatar(url: club.coverImageUrl, name: club.name, slug: club.slug),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                club.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFF7A00),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _Pill('Club Profile'),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _navigateToMembersPage(context);
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white30, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 12,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${club.membersCount} members',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.chevron_right,
                              size: 14,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        club.isMember
            ? _MessagesButton(clubUuid: club.uuid, key: messageButtonKey)
            : _JoinButton(clubUuid: club.uuid),
      ],
    );
  }

  void _navigateToMembersPage(BuildContext context) {
    final bool isAdmin = club.isAdmin ?? false;

    Navigator.pushNamed(
      context,
      RouteNames.clubMembers,
      arguments: {'club': club.slug, 'isAdmin': isAdmin},
    );
  }
}

/* ─────────────────── AVATAR ─────────────────── */

class _MessagesButton extends StatelessWidget {
  final String clubUuid;

  const _MessagesButton({required this.clubUuid, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _navigateToClubChat(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue, width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(Icons.message, color: Colors.blue, size: 18)],
        ),
      ),
    );
  }

  void _navigateToClubChat(BuildContext context) {
    Navigator.pushNamed(context, RouteNames.conversations);
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final String slug;

  const _Avatar({required this.url, required this.name, required this.slug});

  bool get _hasValidUrl =>
      url != null && url!.trim().isNotEmpty && url!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    final icon = clubPlaceholderIcon(name: name, slug: slug);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFF7A00), Color(0xFFFFB347)],
            ),
          ),
          child: CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFF101028),
            child: _hasValidUrl
                ? ClipOval(
                    child: Image.network(
                      url!,
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(icon),
                    ),
                  )
                : _fallback(icon),
          ),
        ),
      ],
    );
  }

  Widget _fallback(IconData icon) {
    return Icon(icon, size: 30, color: Colors.white.withOpacity(0.9));
  }
}

/* ─────────────────── JOIN BUTTON ─────────────────── */

class _JoinButton extends StatelessWidget {
  final String clubUuid;
  final VoidCallback? onJoin;

  const _JoinButton({required this.clubUuid, this.onJoin});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClubProfileCubit, ClubProfileState>(
      builder: (context, state) {
        final isJoining = state.joining;
        final isMember = state.profile?.isMember ?? false;

        // If already a member, show joined state
        if (isMember) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: Colors.green, size: 16),
                SizedBox(width: 6),
                Text(
                  'Joined',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: isJoining
              ? null
              : (onJoin ?? () => context.read<ClubProfileCubit>().joinClub()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF7A00).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF7A00), width: 1.5),
            ),
            child: isJoining
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFFFF7A00),
                    ),
                  )
                : const Text(
                    'Join',
                    style: TextStyle(
                      color: Color(0xFFFF7A00),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
/* ─────────────────── DESCRIPTION ─────────────────── */

class _DescriptionCard extends StatelessWidget {
  final String? text;
  const _DescriptionCard(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text ?? 'No description provided',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}

/* ─────────────────── INCOME ─────────────────── */

class _IncomeCard extends StatelessWidget {
  final ClubProfile club;
  final String clubUuid;

  const _IncomeCard({required this.club, required this.clubUuid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A40), Color(0xFF2E2E6A)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Club Income',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    RouteNames.supportClub,
                    arguments: {
                      'clubUuid': club.uuid,
                      'clubName': club.name,
                      'clubDescription': club.description,
                      'clubAvatar': club.coverImageUrl.toString(),
                    },
                  );
                },
                child: Text(
                  'Donate to Club',
                  style: TextStyle(
                    color: Color(0xFFFF7A00),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.amber,
                child: Icon(Icons.monetization_on, color: Colors.black),
              ),
              const SizedBox(width: 12),
              Text(
                ' ${formatCoin(club.totalIncomeCoins)} Coins',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            club.basicStats == 0
                ? 'No growth data'
                : '+${club.basicStats}% vs last month',
            style: const TextStyle(color: Colors.greenAccent),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClubIncomeDetailsScreen(clubUuid: clubUuid),
                ),
              );
            },
            child: const Text(
              'View Details →',
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

/* ─────────────────── TOP MEMBERS ─────────────────── */

class _TopMembers extends StatelessWidget {
  final List<ClubProfileMember> members;

  const _TopMembers({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Members you know',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final member = members[i];

              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        RouteNames.profileView,
                        arguments: {'userUuid': member.uuid, 'user_slug': ''},
                      );
                    },
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage: member.avatarUrl != null
                          ? NetworkImage(member.avatarUrl!)
                          : null,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 56,
                    child: Text(
                      member.fullname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ─────────────────── UTILS ─────────────────── */

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
