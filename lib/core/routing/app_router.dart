import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/pages/email_verification.dart';
import 'package:moonlight/features/auth/presentation/pages/forget_password.dart';
import 'package:moonlight/features/auth/presentation/pages/login_screen.dart';
import 'package:moonlight/features/auth/presentation/pages/register_screen.dart';
import 'package:moonlight/features/home/presentation/pages/home_screen.dart';
import 'package:moonlight/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:moonlight/features/onboarding/presentation/pages/splash_screen.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/profile/presentation/bloc/interest_bloc.dart';
import 'package:moonlight/features/profile/presentation/bloc/interest_event.dart';
import 'package:moonlight/features/profile/presentation/pages/interest_selection_page.dart';
import 'package:moonlight/features/profile_setup/presentation/bloc/profile_setup_bloc.dart';
import 'package:moonlight/features/profile_setup/presentation/pages/profile_setup_screen.dart';
import 'package:moonlight/features/search/presentation/bloc/search_bloc.dart';
import 'package:moonlight/features/search/presentation/pages/search_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case RouteNames.onboarding:
        return MaterialPageRoute(builder: (_) => OnboardingScreen());

      case RouteNames.login:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthBloc>(),
            child: const LoginScreen(),
          ),
        );

      case RouteNames.register:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthBloc>(),
            child: const RegisterScreen(),
          ),
        );

      case RouteNames.home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ); // or your HomeScreen
      case RouteNames.email_verify:
        return MaterialPageRoute(
          builder: (_) =>
              const EmailVerificationScreen(email: "digitanotion@gmail.com"),
        ); //
      case RouteNames.forget_password:
        return MaterialPageRoute(
          builder: (_) => const ForgetPasswordScreen(),
        ); // forget_password
      case RouteNames.profile_setup:
        return MaterialPageRoute(
          builder:
              (_) => // In your route generator or screen navigation
              BlocProvider(
                create: (context) => sl<ProfileSetupBloc>(),
                child: const ProfileSetupScreen(),
              ),
        ); // profile_setup
      case RouteNames.search:
        return MaterialPageRoute(
          builder:
              (_) => // In your route generator or screen navigation
              BlocProvider(
                create: (context) => sl<SearchBloc>(),
                child: const SearchScreen(),
              ),
        ); //search
      case RouteNames.interests:
        return MaterialPageRoute(
          builder:
              (_) => // In your route generator or screen navigation
              BlocProvider(
                create: (_) => sl<InterestBloc>()..add(const LoadInterests()),
                child: const InterestSelectionPage(),
              ),
        ); //interests
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
