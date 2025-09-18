import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/core/widgets/auth_guard.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/pages/email_verification.dart';
import 'package:moonlight/features/auth/presentation/pages/forget_password.dart';
import 'package:moonlight/features/auth/presentation/pages/login_screen.dart';
import 'package:moonlight/features/auth/presentation/pages/register_screen.dart';
import 'package:moonlight/features/edit_profile/presentation/cubit/edit_profile_cubit.dart';
import 'package:moonlight/features/edit_profile/presentation/pages/edit_profile_screen.dart';
import 'package:moonlight/features/home/presentation/pages/home_screen.dart';
import 'package:moonlight/features/home/presentation/pages/posts_screen.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/domain/repositories/viewer_repository.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/live_viewer_screen.dart';
import 'package:moonlight/features/livestream/domain/entities/live_entities.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_repository.dart';
import 'package:moonlight/features/livestream/presentation/bloc/live_host_bloc.dart';
import 'package:moonlight/features/livestream/presentation/cubits/live_cubits.dart';
import 'package:moonlight/features/livestream/presentation/pages/go_live_screen.dart';
import 'package:moonlight/features/livestream/presentation/pages/live_host_page.dart';
import 'package:moonlight/features/livestream/presentation/pages/live_viewer.dart';
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
      case RouteNames.goLive:
        return MaterialPageRoute(
          builder: (_) => AuthGuard(child: const GoLiveScreen()),
          settings: settings,
        );

      case RouteNames.liveHost:
        final a = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => BlocProvider<LiveHostBloc>(
            create: (_) => GetIt.I<LiveHostBloc>(),
            child: LiveHostPage(
              hostName: a['host_name'] as String,
              hostBadge: a['host_badge'] as String,
              topic: a['topic'] as String,
              initialViewers: a['initial_viewers'] as int? ?? 0,
              startedAtIso:
                  a['started_at'] as String? ??
                  DateTime.now().toIso8601String(),
              avatarUrl: a['avatar_url'] as String?,
            ),
          ),
        );

      case RouteNames.liveViewer:
        {
          final a = (settings.arguments as Map?) ?? {};
          final id = a['id'] as int?;
          final uuid = a['uuid'] as String?;
          final channel = a['channel'] as String?;
          if (id == null || uuid == null || channel == null) {
            // visible, friendly guard
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(
                  child: Text('Unable to open live (missing id/uuid/channel).'),
                ),
              ),
            );
          }

          // Build host card from args (or leave defaults)
          final host = HostInfo(
            name: (a['hostName'] as String?) ?? 'Host',
            title: (a['title'] as String?) ?? 'Live',
            subtitle: '', // you can enrich from feed
            badge: (a['role'] as String?) ?? 'Host',
            avatarUrl:
                (a['hostAvatar'] as String?) ??
                'https://via.placeholder.com/120x120.png?text=LIVE',
          );

          final startedAtIso = (a['startedAt'] as String?);
          final startedAt = startedAtIso == null
              ? null
              : DateTime.tryParse(startedAtIso);

          // ✅ REST will use numeric id, sockets also use numeric id
          final repo = ViewerRepositoryImpl(
            http: GetIt.I<DioClient>(),
            pusher: GetIt.I<PusherService>(),
            livestreamParam: id.toString(), // ✅ REST path uses numeric id
            livestreamIdNumeric: id, // ✅ Pusher channels use numeric id
            channelName: channel,
            initialHost: host,
            startedAt: startedAt,
          );

          return MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) => ViewerBloc(repo)..add(const ViewerStarted()),
              child: LiveViewerScreen(repository: repo),
            ),
            settings: settings,
          );
        }

      case RouteNames.accountSettings:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<AccountSettingsCubit>(),
            child: const AccountSettingsPage(),
          ),
        );

      case RouteNames.postsPage:
        return MaterialPageRoute(builder: (_) => const PostsScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
