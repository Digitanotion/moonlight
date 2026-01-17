import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import '../cubit/profile_page_cubit.dart';
import 'my_profile_screen.dart';

class MyProfileTab extends StatelessWidget {
  const MyProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfilePageCubit>()..load(),
      child: const MyProfileScreen(),
    );
  }
}
