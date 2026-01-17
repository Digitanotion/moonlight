import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/icon_data.dart';
import 'package:moonlight/core/utils/formatting.dart';
import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/clubs/presentation/pages/club_income_details_screen.dart';
import 'package:moonlight/features/clubs/domain/entities/club_profile.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_profile_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_profile_state.dart';
import 'package:moonlight/features/clubs/presentation/pages/support_club_page.dart';

class ClubProfileScreen extends StatefulWidget {
  const ClubProfileScreen({super.key});

  @override
  State<ClubProfileScreen> createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
      body: BlocBuilder<ClubProfileCubit, ClubProfileState>(
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
                            _HeaderMeta(club: club),
                            const SizedBox(height: 30),
                            _DescriptionCard(club.description),
                            const SizedBox(height: 25),
                            _IncomeCard(club: club, clubUuid: club.uuid),
                            const SizedBox(height: 35),
                            _TopMembers(members: club.membersYouKnow),

                            // const SizedBox(height: 24),
                            // _Tabs(controller: _tabs),
                            // const SizedBox(height: 16),
                            // _TabContent(controller: _tabs),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
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
          Icon(Icons.more_vert, color: Colors.white),
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
          // 🔹 ALWAYS render fallback base
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

          // 🔹 Overlay image if valid
          if (_hasValidUrl)
            Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),

          // 🔹 Dark overlay (matches screenshot)
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
  const _HeaderMeta({required this.club});

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
                  Text(
                    '${club.membersCount} members',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        _JoinButton(joined: club.isMember, clubUuid: club.uuid),
      ],
    );
  }
}

/* ─────────────────── AVATAR ─────────────────── */

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

        // Rank badge (unchanged)
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '#12',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
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
  final bool joined;
  final String clubUuid;

  const _JoinButton({required this.joined, required this.clubUuid});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: joined
          ? null
          : () async {
              await context.read<ClubProfileCubit>().repository.joinClub(
                clubUuid,
              );

              context.read<ClubProfileCubit>().load(clubUuid);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: joined ? Colors.white24 : const Color(0xFFFF7A00),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          joined ? 'Joined' : 'Join Club',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
                      'clubUuid': club.uuid, // 🔥 REQUIRED
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
                        arguments: {
                          'userUuid': member.uuid,
                          'user_slug': '', // kept for compatibility
                        },
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

/* ─────────────────── TABS ─────────────────── */

class _Tabs extends StatelessWidget {
  final TabController controller;
  const _Tabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A00), Color(0xFFFFB347)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFFF7A00).withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          _TabLabel(text: 'Posts'),
          _TabLabel(text: 'Livestreams'),
          _TabLabel(text: 'About'),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String text;
  const _TabLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _TabContent extends StatelessWidget {
  final TabController controller;
  const _TabContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: TabBarView(
        controller: controller,
        children: const [
          Center(
            child: Text('Posts', style: TextStyle(color: Colors.white)),
          ),
          Center(
            child: Text('Livestreams', style: TextStyle(color: Colors.white)),
          ),
          Center(
            child: Text('About', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
