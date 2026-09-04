import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/widgets/styled_banner_ad.dart';
import 'package:moonlight/features/clubs/presentation/cubit/suggested_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/suggested_clubs_state.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/club_skeletons.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/discover_club_card.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_state.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/suggested_club_card.dart';
import 'package:moonlight/widgets/top_snack.dart';

import '../cubit/discover_clubs_cubit.dart';
import '../cubit/discover_clubs_state.dart';
import '../cubit/search_clubs_cubit.dart';
import '../cubit/search_clubs_state.dart';

class DiscoverClubsScreen extends StatefulWidget {
  const DiscoverClubsScreen({super.key});

  @override
  State<DiscoverClubsScreen> createState() => _DiscoverClubsScreenState();
}

class _DiscoverClubsScreenState extends State<DiscoverClubsScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  late final SearchClubsCubit _searchCubit;

  @override
  void initState() {
    super.initState();
    _searchCubit = SearchClubsCubit(context.read());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _searchCubit.close();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    // SearchClubsCubit debounces internally (300ms) — just forward.
    _searchCubit.search(q);
    setState(() {}); // refresh the clear button + toggle the results view
  }

  void _clearSearch() {
    _searchController.clear();
    _searchCubit.clear();
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  Future<void> _refresh() async {
    _clearSearch();
    await Future.wait([
      context.read<DiscoverClubsCubit>().load(),
      context.read<SuggestedClubsCubit>().load(),
      context.read<MyClubsCubit>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      floatingActionButton: _CreateFab(
        onTap: () => Navigator.pushNamed(context, RouteNames.createClub),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgTop, AppColors.bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: BlocListener<DiscoverClubsCubit, DiscoverClubsState>(
            listenWhen: (p, n) =>
                p.successMessage != n.successMessage ||
                p.errorMessage != n.errorMessage,
            listener: (context, state) {
              if (state.successMessage != null) {
                TopSnack.success(context, state.successMessage!);
                context.read<DiscoverClubsCubit>().clearMessages();
                // A join succeeded — keep the other surfaces in sync.
                context.read<MyClubsCubit>().load();
                final q = _searchController.text.trim();
                if (q.isNotEmpty) _searchCubit.search(q);
              } else if (state.errorMessage != null) {
                TopSnack.error(context, state.errorMessage!);
                context.read<DiscoverClubsCubit>().clearMessages();
              }
            },
            child: BlocProvider.value(
              value: _searchCubit,
              child: BlocBuilder<SearchClubsCubit, SearchClubsState>(
                builder: (context, search) {
                  final typed = _searchController.text.trim();
                  final searching = typed.isNotEmpty;
                  return RefreshIndicator(
                    color: AppColors.secondary,
                    backgroundColor: AppColors.card,
                    onRefresh: _refresh,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        const SliverToBoxAdapter(child: _Hero()),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SearchHeader(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            onClear: _clearSearch,
                            loading: search.loading,
                            hasText: _searchController.text.isNotEmpty,
                          ),
                        ),
                        if (searching)
                          _SearchResults(state: search, query: typed)
                        else
                          ..._discoverSlivers(context),
                        const SliverToBoxAdapter(child: SizedBox(height: 96)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Discover (no active search) ─────────────────────────────────────────

  List<Widget> _discoverSlivers(BuildContext context) {
    return [
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
      const SliverToBoxAdapter(child: _SectionHeader('Suggested for you')),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      SliverToBoxAdapter(
        child: BlocBuilder<SuggestedClubsCubit, SuggestedClubsState>(
          builder: (context, state) {
            if (state.loading && state.clubs.isEmpty) {
              return const SuggestedClubsSkeleton();
            }
            if (state.clubs.isEmpty) {
              return const _InlineEmpty(
                icon: Icons.auto_awesome_rounded,
                text: 'No suggestions yet — check back soon.',
              );
            }
            return SizedBox(
              height: SuggestedClubCard.height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: state.clubs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final club = state.clubs[i];
                  final joined = state.joined.contains(club.uuid);
                  return BlocBuilder<DiscoverClubsCubit, DiscoverClubsState>(
                    buildWhen: (p, n) =>
                        p.joining.contains(club.uuid) !=
                        n.joining.contains(club.uuid),
                    builder: (context, disc) => SuggestedClubCard(
                      club: club,
                      joined: joined,
                      joining: disc.joining.contains(club.uuid),
                      onJoin: () => _joinSuggested(club.uuid),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
      const SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(child: StyledBannerAd()),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
      SliverToBoxAdapter(
        child: BlocBuilder<MyClubsCubit, MyClubsState>(
          builder: (context, state) => _SectionHeader(
            'Your clubs',
            trailing: state.clubs.isEmpty ? null : '${state.clubs.length}',
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      BlocBuilder<MyClubsCubit, MyClubsState>(
        builder: (context, state) {
          if (state.loading && state.clubs.isEmpty) {
            return const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: ClubRowsSkeleton()),
            );
          }
          if (state.clubs.isEmpty) {
            return const SliverToBoxAdapter(
              child: _EmptyState(
                icon: Icons.groups_2_rounded,
                title: 'You haven’t joined a club yet',
                subtitle:
                    'Join one above, or create your own with the + button.',
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: state.clubs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => DiscoverClubCard(
                club: state.clubs[i],
                joining: false,
                onJoin: () {},
              ),
            ),
          );
        },
      ),
    ];
  }

  Future<void> _joinSuggested(String clubUuid) async {
    await context.read<DiscoverClubsCubit>().join(clubUuid);
    if (!mounted) return;
    context.read<SuggestedClubsCubit>().markJoined(clubUuid);
    context.read<MyClubsCubit>().load();
  }
}

/* ───────────────────────────── hero ───────────────────────────── */

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clubs',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Communities to belong to on Moonlight',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────────── search header ───────────────────────────── */

class _SearchHeader extends SliverPersistentHeaderDelegate {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool loading;
  final bool hasText;

  _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.loading,
    required this.hasText,
  });

  static const double _height = 74;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: _height,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: AppColors.bgTop,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: Colors.white.withOpacity(0.55),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: AppColors.secondary,
                cursorWidth: 1.6,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search clubs',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.secondary,
                ),
              )
            else if (hasText)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withOpacity(0.55),
                  size: 19,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchHeader old) =>
      old.loading != loading ||
      old.hasText != hasText ||
      old.controller != controller ||
      old.focusNode != focusNode;
}

/* ───────────────────────────── search results ───────────────────────────── */

class _SearchResults extends StatelessWidget {
  final SearchClubsState state;

  /// What's currently in the field. While this differs from `state.query` the
  /// cubit's debounced fetch hasn't caught up yet — show the skeleton, not an
  /// empty state.
  final String query;

  const _SearchResults({required this.state, required this.query});

  @override
  Widget build(BuildContext context) {
    final settled = state.query.trim() == query.trim();

    if (!settled || (state.loading && state.results.isEmpty)) {
      return const SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
        sliver: SliverToBoxAdapter(child: ClubRowsSkeleton(count: 4)),
      );
    }
    if (state.results.isEmpty) {
      return const SliverToBoxAdapter(
        child: _EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No clubs found',
          subtitle: 'Try a different name or keyword.',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      sliver: SliverList.separated(
        itemCount: state.results.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final club = state.results[i];
          return BlocBuilder<DiscoverClubsCubit, DiscoverClubsState>(
            buildWhen: (p, n) =>
                p.joining.contains(club.uuid) != n.joining.contains(club.uuid),
            builder: (context, disc) => DiscoverClubCard(
              club: club,
              joining: disc.joining.contains(club.uuid),
              onJoin: () => context.read<DiscoverClubsCubit>().join(club.uuid),
            ),
          );
        },
      ),
    );
  }
}

/* ───────────────────────────── bits ───────────────────────────── */

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailing!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InlineEmpty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white.withOpacity(0.35), size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateFab extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text(
              'Create',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
