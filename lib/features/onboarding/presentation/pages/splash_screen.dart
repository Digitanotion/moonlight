import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/app_router.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 2));

    // Wait for OnboardingBloc to emit the first state
    final onboardingState = await context.read<OnboardingBloc>().stream.first;

    final isFirstLaunch = onboardingState.isFirstLaunch;

    // Trigger auth check
    context.read<AuthBloc>().add(CheckAuthStatusEvent());

    // Wait for auth state
    final authState = await context.read<AuthBloc>().stream.firstWhere(
      (state) => state is AuthAuthenticated || state is AuthUnauthenticated,
    );

    if (isFirstLaunch) {
      Navigator.pushReplacementNamed(context, RouteNames.onboarding);
    } else if (authState is AuthAuthenticated) {
      Navigator.pushReplacementNamed(context, RouteNames.home);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.login);
    }
  }

  // void _navigateToNextScreen() async {
  //   await Future.delayed(const Duration(seconds: 2));

  //   final isFirstLaunch = context.read<OnboardingBloc>().state.isFirstLaunch;

  //   if (isFirstLaunch) {
  //     Navigator.pushReplacementNamed(context, RouteNames.onboarding);
  //   } else {
  //     Navigator.pushReplacementNamed(context, RouteNames.login);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Image.asset(
          AssetPaths.logo, // Add your logo path
          width: 150,
          height: 150,
        ),
      ),
    );
  }
}
