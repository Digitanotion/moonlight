import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/core/widgets/auth_guard.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/pages/email_verification.dart';
import 'package:moonlight/features/auth/presentation/pages/forget_password.dart';
import 'package:moonlight/features/auth/presentation/pages/login_screen.dart';
import 'package:moonlight/features/auth/presentation/pages/register_screen.dart';
import 'package:moonlight/features/create_post/presentation/cubit/create_post_cubit.dart';
import 'package:moonlight/features/create_post/presentation/pages/create_post_screen.dart';
import 'package:moonlight/features/edit_profile/presentation/cubit/edit_profile_cubit.dart';
import 'package:moonlight/features/edit_profile/presentation/pages/edit_profile_screen.dart';
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/feed/presentation/pages/feed_screen.dart';
import 'package:moonlight/features/home/presentation/pages/home_screen.dart';
import 'package:moonlight/features/home/presentation/pages/posts_screen.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/live_viewer_screen.dart';
import 'package:moonlight/features/livestream/domain/entities/live_end_analytics.dart';
import 'package:moonlight/features/livestream/presentation/bloc/live_host_bloc.dart';
import 'package:moonlight/features/livestream/presentation/pages/go_live_screen.dart';
import 'package:moonlight/features/livestream/presentation/pages/list_viewers.dart';
import 'package:moonlight/features/livestream/presentation/pages/live_host_page.dart';
import 'package:moonlight/features/livestream/presentation/pages/livestream_ended.dart';
import 'package:moonlight/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:moonlight/features/onboarding/presentation/pages/splash_screen.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/post_view/domain/repositories/post_repository.dart';
import 'package:moonlight/features/post_view/presentation/cubit/post_cubit.dart';
import 'package:moonlight/features/post_view/presentation/pages/comments_page.dart';
import 'package:moonlight/features/post_view/presentation/pages/post_view_screen.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_page_cubit.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_setup_cubit.dart';
import 'package:moonlight/features/profile_setup/presentation/pages/my_profile_screen.dart';
import 'package:moonlight/features/profile_setup/presentation/pages/profile_setup_screen.dart';
import 'package:moonlight/features/profile_view/presentation/cubit/profile_cubit.dart';
import 'package:moonlight/features/profile_view/presentation/pages/profile_view.dart';
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
        return MaterialPageRoute(builder: (context) => const SplashScreen());

      case RouteNames.onboarding:
        return MaterialPageRoute(builder: (context) => OnboardingScreen());

      case RouteNames.login:
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => sl<AuthBloc>(),
            child: const LoginScreen(),
          ),
        );

      case RouteNames.register:
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => sl<AuthBloc>(),
            child: const RegisterScreen(),
          ),
        );

      case RouteNames.home:
        return MaterialPageRoute(builder: (context) => const HomeScreen());

      case RouteNames.email_verify:
        return MaterialPageRoute(
          builder: (context) =>
              const EmailVerificationScreen(email: "digitanotion@gmail.com"),
        );

      case RouteNames.forget_password:
        return MaterialPageRoute(
          builder: (context) => const ForgetPasswordScreen(),
        );

      case RouteNames.search:
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => sl<SearchBloc>(),
            child: const SearchScreen(),
          ),
        );

      case RouteNames.profile_setup:
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => sl<ProfileSetupCubit>(),
            child: const ProfileSetupScreen(),
          ),
        );

      case RouteNames.interests:
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => sl<UserInterestCubit>(),
            child: const UserInterestScreen(),
          ),
        );

      case RouteNames.editProfile:
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => sl<EditProfileCubit>(),
            child: const EditProfileScreen(),
          ),
        );

      case RouteNames.myProfile:
        return MaterialPageRoute(
          builder: (context) => AuthGuard(
            child: BlocProvider<ProfilePageCubit>(
              create: (context) => sl<ProfilePageCubit>()..load(),
              child: const MyProfileScreen(),
            ),
          ),
          settings: settings,
        );

      case RouteNames.profileView:
        {
          // robust handling: require userUuid; if missing show friendly screen.
          final a = (settings.arguments as Map?) ?? const {};
          final userUuid = (a['userUuid'] as String?) ?? '';

          if (userUuid.isEmpty) {
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 72,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Invalid Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No user identifier was provided. Returning to feed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // Try to create ProfileCubit via GetIt, but catch and show helpful error
          try {
            return MaterialPageRoute(
              builder: (context) => BlocProvider<ProfileCubit>(
                create: (context) => sl<ProfileCubit>()..load(userUuid),
                child: const ProfileViewPage(),
              ),
              settings: settings,
            );
          } catch (err) {
            debugPrint('❌ Failed to create ProfileCubit via GetIt: $err');
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 72,
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Profile unavailable',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'There was an internal configuration error. Please ensure dependency injection is initialized before navigating to the profile view.\n\nError: ${err.toString()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        }

      case RouteNames.goLive:
        return MaterialPageRoute(
          builder: (context) => AuthGuard(child: const GoLiveScreen()),
          settings: settings,
        );

      case RouteNames.liveHost:
        final a = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => BlocProvider<LiveHostBloc>(
            create: (context) => GetIt.I<LiveHostBloc>(),
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
            return MaterialPageRoute(
              builder: (context) => const Scaffold(
                body: Center(
                  child: Text('Unable to open live (missing id/uuid/channel).'),
                ),
              ),
            );
          }

          final host = HostInfo(
            name: (a['hostName'] as String?) ?? 'Host',
            title: (a['title'] as String?) ?? 'Live',
            subtitle: '',
            badge: (a['role'] as String?) ?? 'Host',
            avatarUrl:
                (a['hostAvatar'] as String?) ??
                'https://via.placeholder.com/120x120.png?text=LIVE',
          );

          final startedAtIso = (a['startedAt'] as String?);
          final startedAt = startedAtIso == null
              ? null
              : DateTime.tryParse(startedAtIso);

          final repo = ViewerRepositoryImpl(
            http: GetIt.I<DioClient>(),
            pusher: GetIt.I<PusherService>(),
            authLocalDataSource: GetIt.I<AuthLocalDataSource>(),
            livestreamParam: id.toString(),
            livestreamIdNumeric: id,
            channelName: channel,
            initialHost: host,
            startedAt: startedAt,
          );

          return MaterialPageRoute(
            builder: (context) => BlocProvider(
              create: (context) => ViewerBloc(repo)..add(const ViewerStarted()),
              child: LiveViewerScreen(repository: repo),
            ),
            settings: settings,
          );
        }

      case RouteNames.createPost:
        return MaterialPageRoute(
          builder: (context) => BlocProvider<CreatePostCubit>(
            create: (context) => sl<CreatePostCubit>(),
            child: const CreatePostScreen(),
          ),
          settings: settings,
        );

      case RouteNames.accountSettings:
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => sl<AccountSettingsCubit>(),
            child: const AccountSettingsPage(),
          ),
        );

      case RouteNames.postsPage:
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => sl<FeedCubit>(),
            child: const FeedScreen(),
          ),
        );

      case RouteNames.postView:
        {
          final a = (settings.arguments as Map?) ?? const {};
          final postId = (a['postId'] as String?) ?? 'demo-post-1';
          final isOwner = (a['isOwner'] as bool?) ?? false;

          if (postId.isEmpty) {
            return MaterialPageRoute(
              builder: (context) => const Scaffold(
                body: Center(child: Text('Missing postId for PostView')),
              ),
            );
          }

          // ✅ METHOD 1: Try GetIt factory param first
          try {
            return MaterialPageRoute(
              builder: (context) => BlocProvider(
                create: (context) => sl<PostCubit>(param1: postId)..load(),
                child: PostViewScreen(isOwner: isOwner, postId: postId),
              ),
              settings: settings,
            );
          } catch (e) {
            debugPrint('❌ GetIt factory param failed: $e');

            // ✅ METHOD 2: Fallback to direct creation
            return MaterialPageRoute(
              builder: (context) => BlocProvider(
                create: (context) =>
                    PostCubit(sl<PostRepository>(), postId)..load(),
                child: PostViewScreen(isOwner: isOwner, postId: postId),
              ),
              settings: settings,
            );
          }
        }
      case RouteNames.listViewers:
        return MaterialPageRoute(builder: (context) => const ViewersListPage());

      case RouteNames.livestreamEnded:
        final args = settings.arguments as LiveEndAnalytics?;
        return MaterialPageRoute(
          builder: (context) => LivestreamEndedScreen(analytics: args),
        );

      case RouteNames.postComments:
        {
          final a = (settings.arguments as Map?) ?? const {};
          final postCubit = a['postCubit'] as PostCubit;
          return MaterialPageRoute(
            builder: (context) => BlocProvider.value(
              value: postCubit,
              child: const CommentsPage(),
            ),
            settings: settings,
          );
        }

      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
