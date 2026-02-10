import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/presentation/cubit/suggested_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/suggested_clubs_state.dart';
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
  late TextEditingController _searchController;
  Timer? _debounceTimer;
  late SearchClubsCubit _searchCubit;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchCubit = SearchClubsCubit(context.read());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _searchCubit.close();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchCubit.search(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchCubit.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.secondary,
        onPressed: () {
          Navigator.pushNamed(context, RouteNames.createClub);
        },
        child: const Icon(Icons.add, color: Colors.white),
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
          child: BlocListener<DiscoverClubsCubit, DiscoverClubsState>(
            listener: (context, state) {
              if (state.errorMessage != null) {
                TopSnack.error(context, state.errorMessage!);
                context.read<DiscoverClubsCubit>().clearMessages();
              }
              if (state.successMessage != null) {
                TopSnack.success(context, state.successMessage!);
                context.read<DiscoverClubsCubit>().clearMessages();
              }
            },
            child: BlocProvider.value(
              value: _searchCubit,
              child: BlocBuilder<SearchClubsCubit, SearchClubsState>(
                builder: (context, searchState) {
                  return RefreshIndicator(
                    color: AppColors.secondary,
                    onRefresh: () async {
                      _clearSearch();
                      await Future.wait([
                        context.read<DiscoverClubsCubit>().load(),
                        context.read<SuggestedClubsCubit>().load(),
                        context.read<MyClubsCubit>().load(),
                      ]);
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          pinned: true,
                          floating: false,
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          expandedHeight: 120,
                          flexibleSpace: FlexibleSpaceBar(
                            background: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.bgTop, AppColors.bgBottom],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              padding: const EdgeInsets.only(top: 16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _header(),
                                    const SizedBox(height: 16),
                                    _buildSearchBar(searchState),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        if (searchState.query.isEmpty)
                          _buildRegularContent(context)
                        else
                          _buildSearchResults(context, searchState),
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

  Widget _buildSearchBar(SearchClubsState searchState) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.7),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search clubs by name or description...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: AppColors.secondary,
              cursorWidth: 1.5,
            ),
          ),
          if (searchState.loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.secondary,
                ),
              ),
            )
          else if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
              onPressed: _clearSearch,
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildRegularContent(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _section('Suggested Clubs'),
              const SizedBox(height: 12),

              BlocBuilder<SuggestedClubsCubit, SuggestedClubsState>(
                builder: (context, state) {
                  if (state.loading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (state.clubs.isEmpty) {
                    return const Text(
                      'No suggestions available',
                      style: TextStyle(color: Colors.white54),
                    );
                  }

                  return SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.clubs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        return SuggestedClubCard(
                          club: state.clubs[i],
                          joined: state.joined.contains(state.clubs[i].uuid),
                          onJoin: () async {
                            final clubId = state.clubs[i].uuid;
                            await context.read<DiscoverClubsCubit>().join(
                              clubId,
                            );
                            context.read<SuggestedClubsCubit>().markJoined(
                              clubId,
                            );
                            context.read<MyClubsCubit>().load();
                          },
                        );
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),
              _section('My Clubs'),
              const SizedBox(height: 12),

              BlocBuilder<MyClubsCubit, MyClubsState>(
                builder: (context, state) {
                  if (state.loading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (state.clubs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'You have not joined any clubs yet',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  return _myClubs(state.clubs);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, SearchClubsState state) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (state.loading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          if (state.results.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    color: Colors.white54,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No clubs found',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  Text(
                    'Try a different search term',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final club = state.results[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    // Whole card is tappable for navigation
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            RouteNames.clubProfile,
                            arguments: {'clubUuid': club.uuid},
                          );
                        },
                        // Empty child to ensure gestures work
                        child: const SizedBox.expand(),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.primary2.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.groups,
                              color: AppColors.secondary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  club.name ?? 'Unnamed Club',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                if (club.description?.isNotEmpty == true)
                                  Text(
                                    club.description ?? '',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // Icon(
                                    //   Icons.location_on,
                                    //   size: 14,
                                    //   color: Colors.white.withOpacity(0.6),
                                    // ),
                                    // const SizedBox(width: 4),
                                    // Text(
                                    //   club.location ?? 'No location',
                                    //   style: TextStyle(
                                    //     color: Colors.white.withOpacity(0.6),
                                    //     fontSize: 12,
                                    //   ),
                                    // ),
                                    // const Spacer(),
                                    Icon(
                                      Icons.people,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${club.membersCount ?? 0} members',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Join Button - Separate gesture detector that stops propagation
                          if (!(club.isMember ?? false))
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: SizedBox(
                                width: 80,
                                child: GestureDetector(
                                  onTap: () async {
                                    // await context
                                    //     .read<DiscoverClubsCubit>()
                                    //     .join(club.uuid);
                                    // _searchCubit.search(state.query);
                                    // context.read<MyClubsCubit>().load();
                                    Navigator.pushNamed(
                                      context,
                                      RouteNames.clubProfile,
                                      arguments: {'clubUuid': club.uuid},
                                    );
                                  },
                                  child: Material(
                                    color: AppColors.secondary,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Center(
                                        child:
                                            context
                                                .watch<DiscoverClubsCubit>()
                                                .state
                                                .joining
                                                .contains(club.uuid)
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Text(
                                                'Profile',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }, childCount: state.loading ? 1 : max(1, state.results.length)),
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text(
          'Clubs',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _section(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _myClubs(List clubs) {
    return Column(
      children: clubs.map((club) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DiscoverClubCard(club: club, joining: false, onJoin: () {}),
        );
      }).toList(),
    );
  }
}
