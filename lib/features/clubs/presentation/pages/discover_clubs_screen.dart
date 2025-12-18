import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/discover_club_card.dart';
import 'package:moonlight/widgets/top_snack.dart';
import '../cubit/discover_clubs_cubit.dart';
import '../cubit/discover_clubs_state.dart';

class DiscoverClubsScreen extends StatelessWidget {
  const DiscoverClubsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ClubsRepository>.value(
      value: sl<ClubsRepository>(),
      child: BlocProvider(
        create: (_) => DiscoverClubsCubit(sl())..load(),
        child: Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Discover Clubs',
              style: TextStyle(fontWeight: FontWeight.w800),
            ), //sdsdsd
          ),
          body: BlocListener<DiscoverClubsCubit, DiscoverClubsState>(
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
            child: BlocBuilder<DiscoverClubsCubit, DiscoverClubsState>(
              builder: (context, state) {
                if (state.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.clubs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No public clubs available',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.clubs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final club = state.clubs[i];
                    return DiscoverClubCard(
                      club: club,
                      joining: state.joining.contains(club.uuid),
                      onJoin: () =>
                          context.read<DiscoverClubsCubit>().join(club.uuid),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
