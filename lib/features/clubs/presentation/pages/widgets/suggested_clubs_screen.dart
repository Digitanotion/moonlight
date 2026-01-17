import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/presentation/cubit/discover_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/discover_clubs_state.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/discover_club_card.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_state.dart';
import 'package:moonlight/features/home/presentation/widgets/bottom_nav.dart';
import 'package:moonlight/widgets/top_snack.dart';

class SuggestedClubsScreen extends StatelessWidget {
  const SuggestedClubsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ClubsRepository>.value(
      value: sl<ClubsRepository>(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => DiscoverClubsCubit(sl())..load()),
          BlocProvider(create: (_) => MyClubsCubit(sl())..load()),
        ],
        child: Scaffold(
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.secondary,
            onPressed: () {
              Navigator.pushNamed(context, '/create-club');
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      _searchBar(),
                      const SizedBox(height: 16),
                      _filters(),
                      const SizedBox(height: 24),

                      /// ================= SUGGESTED =================
                      _section('Suggested Clubs'),
                      const SizedBox(height: 12),
                      BlocBuilder<DiscoverClubsCubit, DiscoverClubsState>(
                        builder: (context, state) {
                          if (state.loading) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          }

                          return _suggested(state.clubs, state, context);
                        },
                      ),

                      const SizedBox(height: 28),

                      /// ================= MY CLUBS =================
                      _section('My Clubs'),
                      const SizedBox(height: 12),
                      BlocBuilder<MyClubsCubit, MyClubsState>(
                        builder: (context, state) {
                          if (state.loading) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= UI (UNCHANGED) =================

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
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
          Icon(Icons.settings, size: 20, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        children: [
          Icon(Icons.search, color: AppColors.secondaryText),
          SizedBox(width: 12),
          Text(
            'Search for clubs',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    final items = ['All', 'Popular', 'New', 'Nearby'];
    return Row(
      children: items.map((e) {
        final active = e == 'All';
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary2
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              e,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.white70,
              ),
            ),
          ),
        );
      }).toList(),
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

  Widget _suggested(
    List clubs,
    DiscoverClubsState state,
    BuildContext context,
  ) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: clubs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final club = clubs[i];
          return SizedBox(
            width: 260,
            child: DiscoverClubCard(
              club: club,
              joining: state.joining.contains(club.uuid),
              onJoin: () => context.read<DiscoverClubsCubit>().join(club.uuid),
              compact: true,
            ),
          );
        },
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
