import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/widgets/auth_guard.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/pages/email_verification.dart';
import 'package:moonlight/features/auth/presentation/pages/forget_password.dart';
import 'package:moonlight/features/auth/presentation/pages/login_screen.dart';
import 'package:moonlight/features/auth/presentation/pages/register_screen.dart';
import 'package:moonlight/features/edit_profile/presentation/cubit/edit_profile_cubit.dart';
import 'package:moonlight/features/edit_profile/presentation/pages/edit_profile_screen.dart';
import 'package:moonlight/features/home/presentation/pages/home_screen.dart';
import 'package:moonlight/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:moonlight/features/onboarding/presentation/pages/splash_screen.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_page_cubit.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_setup_cubit.dart';
import 'package:moonlight/features/profile_setup/presentation/pages/my_profile_screen.dart';
import 'package:moonlight/features/profile_setup/presentation/pages/profile_setup_screen.dart';

import 'package:moonlight/features/search/presentation/bloc/search_bloc.dart';
import 'package:moonlight/features/search/presentation/pages/search_screen.dart';
import 'package:moonlight/features/settings/presentation/cubit/account_settings_cubit.dart';
import 'package:moonlight/features/settings/presentation/pages/account_settings_page.dart';
import 'package:moonlight/features/user_interest/presentation/cubit/user_interest_cubit.dart';
import 'package:moonlight/features/user_interest/presentation/pages/user_interest_screen.dart';

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
      // profile_setup
      case RouteNames.search:
        return MaterialPageRoute(
          builder:
              (_) => // In your route generator or screen navigation
              BlocProvider(
                create: (context) => sl<SearchBloc>(),
                child: const SearchScreen(),
              ),
        ); //search

      case RouteNames.profile_setup:
        return MaterialPageRoute(
          builder:
              (_) => // In your route generator or screen navigation
              BlocProvider(
                create: (context) => sl<ProfileSetupCubit>(),
                child: const ProfileSetupScreen(),
              ),
        );

      case RouteNames.interests:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<UserInterestCubit>(),
            child: const UserInterestScreen(),
          ),
        );
      case RouteNames.editProfile:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<EditProfileCubit>(),
            child: const EditProfileScreen(),
          ),
        );
      case RouteNames.myProfile:
        return MaterialPageRoute(
          builder: (_) => AuthGuard(
            child: BlocProvider<ProfilePageCubit>(
              create: (_) => sl<ProfilePageCubit>()..load(),
              child: const MyProfileScreen(),
            ),
          ),
          settings: settings,
        );

      case RouteNames.accountSettings:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<AccountSettingsCubit>(),
            child: const AccountSettingsPage(),
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
