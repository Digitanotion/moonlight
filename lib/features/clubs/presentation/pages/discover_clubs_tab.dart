import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/presentation/cubit/discover_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/suggested_clubs_cubit.dart';
import 'discover_clubs_screen.dart';

class DiscoverClubsTab extends StatelessWidget {
  const DiscoverClubsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<ClubsRepository>.value(
      value: sl<ClubsRepository>(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => sl<DiscoverClubsCubit>()..load()),
          BlocProvider(create: (_) => sl<MyClubsCubit>()..load()),
          BlocProvider(create: (_) => sl<SuggestedClubsCubit>()..load()),
        ],
        child: const DiscoverClubsScreen(),
      ),
    );
  }
}
