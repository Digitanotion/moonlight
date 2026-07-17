// lib/features/search/presentation/pages/search_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';
import 'package:moonlight/features/search/presentation/bloc/search_bloc.dart';
import 'package:moonlight/features/search/presentation/widgets/empty_search_state.dart';
import 'package:moonlight/features/search/presentation/widgets/search_skeletons.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController;
  late final SearchBloc _searchBloc;
  final FocusNode _searchFocus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchBloc = BlocProvider.of<SearchBloc>(context);
    _searchBloc.add(LoadTrendingContent());
    _searchFocus.addListener(() {
      setState(() => _focused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<SearchBloc, SearchState>(
            builder: (context, state) {
              return Column(
                children: [
                  _SearchBarField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    focused: _focused,
                    onChanged: (q) => _searchBloc.add(SearchQueryChanged(q)),
                    onClear: () {
                      _searchController.clear();
                      _searchBloc.add(ClearSearch());
                    },
                  ),
                  Expanded(child: _buildContent(state)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(SearchState state) {
    if (state.query.isNotEmpty) {
      switch (state.status) {
        case SearchStatus.loading:
          return const _SearchResultsSkeleton();
        case SearchStatus.empty:
          return EmptySearchState(query: state.query);
        case SearchStatus.success:
          return _buildSearchResults(state);
        case SearchStatus.failure:
          return _ErrorState(message: state.errorMessage ?? 'Search failed');
        case SearchStatus.initial:
        default:
          return _buildInitialContent(state);
      }
    }
    return _buildInitialContent(state);
  }

  Widget _buildInitialContent(SearchState state) {
    final hasAnyContent = state.suggestedUsers.isNotEmpty ||
        state.popularClubs.isNotEmpty ||
        state.trendingTags.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        // if (state.trendingTags.isNotEmpty || state.isLoadingTrending)
        //   _SectionHeader(
        //     icon: Icons.local_fire_department_rounded,
        //     title: 'Trending',
        //     padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        //   ),
        // if (state.isLoadingTrending)
        //   _TrendingTagsSkeleton()
        // else if (state.trendingTags.isNotEmpty)
        //   _TrendingTagsRow(tags: state.trendingTags),

        const SizedBox(height: 28),

        _SectionHeader(
          icon: Icons.auto_awesome_rounded,
          title: 'Suggested for you',
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        ),
        if (state.isLoadingUsers)
          const _SuggestedUsersSkeletonRow()
        else if (state.suggestedUsers.isEmpty)
          const _InlineEmptyHint(text: 'No suggestions yet — follow a few creators to get started')
        else
          _SuggestedUsersCarousel(
            users: state.suggestedUsers,
            onOpenProfile: _openUserProfile,
          ),

        const SizedBox(height: 30),

        _SectionHeader(
          icon: Icons.groups_2_rounded,
          title: 'Clubs to explore',
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        ),
        if (state.isLoadingClubs)
          const _ClubsSkeletonRow()
        else if (state.popularClubs.isEmpty)
          const _InlineEmptyHint(text: 'No clubs to show right now')
        else
          _ClubsCarousel(
            clubs: state.popularClubs,
            onOpenClub: _openClub,
          ),

        const SizedBox(height: 36),

        if (!hasAnyContent)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 36),
            child: Center(
              child: _DiscoverHint(),
            ),
          ),
      ],
    );
  }

  void _openUserProfile(UserResult user) {
    if (user.id.isEmpty) return;
    Navigator.pushNamed(
      context,
      RouteNames.profileView,
      arguments: {'userUuid': user.id, 'user_slug': user.username},
    );
  }

  void _openClub(ClubResult club) {
    Navigator.pushNamed(
      context,
      RouteNames.clubProfile,
      arguments: {'clubUuid': club.id},
    );
  }

  Widget _buildSearchResults(SearchState state) {
    final users = state.results.whereType<UserResult>().toList();
    final clubs = state.results.whereType<ClubResult>().toList();
    final tags = state.results.whereType<TagResult>().toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (users.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.person_rounded,
            title: 'People',
            padding: const EdgeInsets.only(bottom: 10),
          ),
          ...users.map(
            (u) => _SearchUserTile(user: u, onTap: () => _openUserProfile(u)),
          ),
          const SizedBox(height: 22),
        ],
        if (clubs.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.groups_2_rounded,
            title: 'Clubs',
            padding: const EdgeInsets.only(bottom: 10),
          ),
          ...clubs.map(
            (c) => _SearchClubTile(club: c, onTap: () => _openClub(c)),
          ),
          const SizedBox(height: 22),
        ],
        if (tags.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.tag_rounded,
            title: 'Tags',
            padding: const EdgeInsets.only(bottom: 10),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tags.map((t) => _TagChip(tag: t)).toList(),
          ),
        ],
        if (users.isEmpty && clubs.isEmpty && tags.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: Text(
                'No results',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Search bar — pill shape, glows softly on focus ─────────────────────────
class _SearchBarField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBarField({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.dark.withOpacity(0.55),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: focused
                ? AppColors.secondary.withOpacity(0.7)
                : Colors.white.withOpacity(0.08),
            width: focused ? 1.4 : 1,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.25),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              Icons.search_rounded,
              color: focused ? AppColors.secondary : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                style: const TextStyle(color: AppColors.textWhite, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Search creators, clubs or tags',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14.5),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: controller.text.isNotEmpty
                  ? IconButton(
                      key: const ValueKey('clear'),
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary, size: 20),
                      onPressed: onClear,
                    )
                  : const SizedBox(width: 8, key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final EdgeInsets padding;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.headlineLarge.copyWith(
              color: AppColors.textWhite,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmptyHint extends StatelessWidget {
  final String text;
  const _InlineEmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
      ),
    );
  }
}

class _DiscoverHint extends StatelessWidget {
  const _DiscoverHint();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.secondary.withOpacity(0.25),
                AppColors.primary.withOpacity(0.15),
              ],
            ),
          ),
          child: const Icon(Icons.explore_rounded,
              color: AppColors.textWhite, size: 28),
        ),
        const SizedBox(height: 16),
        const Text(
          'Discover Amazing Content',
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Start searching to find creators, clubs and trending content',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.4),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 40),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Trending tags row — pill chips with a subtle gradient border ──────────
class _TrendingTagsRow extends StatelessWidget {
  final List<TagResult> tags;
  const _TrendingTagsRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _TagChip(tag: tags[i], trending: true),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final TagResult tag;
  final bool trending;
  const _TagChip({required this.tag, this.trending = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.dark.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trending) ...[
            const Icon(Icons.trending_up_rounded, size: 13, color: AppColors.secondary),
            const SizedBox(width: 5),
          ],
          Text(
            '#${tag.name}',
            style: const TextStyle(
              color: AppColors.textWhite,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggested users — horizontal carousel, gradient avatar ring ───────────
class _SuggestedUsersCarousel extends StatelessWidget {
  final List<UserResult> users;
  final ValueChanged<UserResult> onOpenProfile;
  const _SuggestedUsersCarousel({required this.users, required this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _SuggestedUserCard(
          user: users[i],
          onTap: () => onOpenProfile(users[i]),
        ),
      ),
    );
  }
}

class _SuggestedUserCard extends StatefulWidget {
  final UserResult user;
  final VoidCallback onTap;
  const _SuggestedUserCard({required this.user, required this.onTap});

  @override
  State<_SuggestedUserCard> createState() => _SuggestedUserCardState();
}

class _SuggestedUserCardState extends State<_SuggestedUserCard> {
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 128,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.dark.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondary,
                    AppColors.secondary.withOpacity(0.3),
                  ],
                ),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.dark,
                backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                    ? const Icon(Icons.person_rounded, color: AppColors.textWhite)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '@${user.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 10),
            _PillButton(
              label: _following ? 'Following' : 'Follow',
              filled: !_following,
              onTap: () => setState(() => _following = !_following),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Clubs carousel — cover-image cards with gradient overlay ──────────────
class _ClubsCarousel extends StatelessWidget {
  final List<ClubResult> clubs;
  final ValueChanged<ClubResult> onOpenClub;
  const _ClubsCarousel({required this.clubs, required this.onOpenClub});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: clubs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _ClubCard(
          club: clubs[i],
          onTap: () => onOpenClub(clubs[i]),
        ),
      ),
    );
  }
}

class _ClubCard extends StatefulWidget {
  final ClubResult club;
  final VoidCallback onTap;
  const _ClubCard({required this.club, required this.onTap});

  @override
  State<_ClubCard> createState() => _ClubCardState();
}

class _ClubCardState extends State<_ClubCard> {
  bool _joined = false;

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final hasCover = club.coverImageUrl != null && club.coverImageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 152,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            hasCover
                ? Image.network(
                    club.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary.withOpacity(0.25),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.4),
                          AppColors.dark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.groups_2_rounded,
                          color: Colors.white38, size: 34),
                    ),
                  ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                  stops: [0, 0.75],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${club.membersCount.formatCount()} members',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  _PillButton(
                    label: _joined ? 'Joined' : 'Join',
                    filled: !_joined,
                    compact: true,
                    onTap: () => setState(() => _joined = !_joined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared pill button (Follow/Join), animated fill state ─────────────────
class _PillButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool compact;
  final VoidCallback onTap;
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: filled ? AppColors.secondary : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: filled
              ? null
              : Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 11.5 : 12.5,
          ),
        ),
      ),
    );
  }
}

// ── Search results tiles ───────────────────────────────────────────────────
class _SearchUserTile extends StatelessWidget {
  final UserResult user;
  final VoidCallback onTap;
  const _SearchUserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dark.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.dark.withOpacity(0.4),
                  backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                      ? const Icon(Icons.person_rounded, color: AppColors.textWhite)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchClubTile extends StatelessWidget {
  final ClubResult club;
  final VoidCallback onTap;
  const _SearchClubTile({required this.club, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasCover = club.coverImageUrl != null && club.coverImageUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dark.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: hasCover
                        ? Image.network(club.coverImageUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.groups_2_rounded, color: AppColors.textWhite),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${club.membersCount.formatCount()} members',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Skeletons ───────────────────────────────────────────────────────────────
class _TrendingTagsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => shimmerBox(w: 78, h: 40, r: BorderRadius.circular(20)),
      ),
    );
  }
}

class _SuggestedUsersSkeletonRow extends StatelessWidget {
  const _SuggestedUsersSkeletonRow();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: 128,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.dark.withOpacity(0.35),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              shimmerBox(w: 60, h: 60, r: BorderRadius.circular(30)),
              const SizedBox(height: 10),
              shimmerBox(w: 80, h: 12),
              const SizedBox(height: 6),
              shimmerBox(w: 60, h: 10),
              const SizedBox(height: 10),
              shimmerBox(w: 70, h: 24, r: BorderRadius.circular(20)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClubsSkeletonRow extends StatelessWidget {
  const _ClubsSkeletonRow();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) =>
            shimmerBox(w: 152, h: 176, r: BorderRadius.circular(20)),
      ),
    );
  }
}

class _SearchResultsSkeleton extends StatelessWidget {
  const _SearchResultsSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dark.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            shimmerBox(w: 44, h: 44, r: BorderRadius.circular(22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  shimmerBox(w: 120, h: 14),
                  const SizedBox(height: 6),
                  shimmerBox(w: 80, h: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension FormatCount on int {
  String formatCount() {
    if (this >= 1000000) return '${(this / 1000000).toStringAsFixed(1)}M';
    if (this >= 1000) return '${(this / 1000).toStringAsFixed(1)}k';
    return toString();
  }
}