import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_state.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/club_card.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/club_skeleton.dart';
import 'package:moonlight/features/clubs/presentation/pages/widgets/create_edit_club_sheet.dart';

class MyClubsTab extends StatelessWidget {
  const MyClubsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyClubsCubit, MyClubsState>(
      builder: (context, state) {
        if (state.loading) {
          return const ClubSkeletonList();
        }

        if (state.clubs.isEmpty) {
          return _EmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CreateClubCTA(),
            const SizedBox(height: 12),
            ...state.clubs.map(
              (club) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClubCard(club: club),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CreateClubCTA extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await showCreateEditClubSheet(context);
        context.read<MyClubsCubit>().refresh();
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A00), Color(0xFFFF9F43)],
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Create New Club',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.groups_outlined, size: 72, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'No clubs yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Create a club or join one to start collaborating.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
