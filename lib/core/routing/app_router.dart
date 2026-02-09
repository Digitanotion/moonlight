import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/core/widgets/auth_guard.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/pages/email_verification.dart';
import 'package:moonlight/features/auth/presentation/pages/forget_password.dart';
import 'package:moonlight/features/auth/presentation/pages/login_screen.dart';
import 'package:moonlight/features/auth/presentation/pages/register_screen.dart';
import 'package:moonlight/features/chat/data/models/chat_conversations.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/chat/presentation/pages/chat_screen.dart';
import 'package:moonlight/features/chat/presentation/pages/conversations_screen.dart';
import 'package:moonlight/features/chat/presentation/pages/cubit/chat_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_members_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_profile_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/discover_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/donate_club_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/edit_club_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/pages/club_members_page.dart';
import 'package:moonlight/features/clubs/presentation/pages/club_members_page_user.dart';
import 'package:moonlight/features/clubs/presentation/pages/club_profile_screen.dart';
import 'package:moonlight/features/clubs/presentation/pages/create_club_screen.dart';
import 'package:moonlight/features/clubs/presentation/pages/discover_clubs_screen.dart';
import 'package:moonlight/features/clubs/presentation/pages/edit_club_screen.dart';
import 'package:moonlight/features/clubs/presentation/pages/support_club_page.dart';
import 'package:moonlight/features/create_post/presentation/cubit/create_post_cubit.dart';
import 'package:moonlight/features/create_post/presentation/pages/create_post_screen.dart';
import 'package:moonlight/features/edit_profile/presentation/cubit/edit_profile_cubit.dart';
import 'package:moonlight/features/edit_profile/presentation/pages/edit_profile_screen.dart';
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/feed/presentation/pages/feed_screen.dart';
import 'package:moonlight/features/gift_coins/presentation/cubit/transfer_cubit.dart';
import 'package:moonlight/features/gift_coins/presentation/pages/gift_coins_page.dart';
import 'package:moonlight/features/home/presentation/pages/app_shell.dart';
import 'package:moonlight/features/home/presentation/pages/home_screen.dart';
import 'package:moonlight/features/home/presentation/pages/posts_screen.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/live_viewer_screen.dart';
import 'package:moonlight/features/live_viewer/presentation/screens/live_viewer_orchestrator.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/network_monitor_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/reconnection_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/role_change_service.dart';
import 'package:moonlight/features/livestream/domain/entities/live_end_analytics.dart';
import 'package:moonlight/features/livestream/presentation/bloc/live_host_bloc.dart';
import 'package:moonlight/features/livestream/presentation/pages/go_live_screen.dart';
import 'package:moonlight/features/livestream/presentation/pages/list_viewers.dart';
import 'package:moonlight/features/livestream/presentation/pages/live_host_page.dart';
import 'package:moonlight/features/livestream/presentation/pages/livestream_ended.dart';
import 'package:moonlight/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:moonlight/features/notifications/presentation/pages/notifications_screen.dart';
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
import 'package:moonlight/features/settings/presentation/pages/blocked_users_page.dart';
import 'package:moonlight/features/settings/presentation/pages/change_email_page.dart';
import 'package:moonlight/features/settings/presentation/pages/change_username_page.dart';
import 'package:moonlight/features/tests/debug_screen.dart';
import 'package:moonlight/features/user_interest/presentation/cubit/user_interest_cubit.dart';
import 'package:moonlight/features/user_interest/presentation/pages/user_interest_screen.dart';
import 'package:moonlight/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:moonlight/features/wallet/presentation/pages/buy_coins_screen.dart';
import 'package:moonlight/features/wallet/presentation/pages/reset_pin_page.dart';
import 'package:moonlight/features/wallet/presentation/pages/set_new_pin_page.dart';
import 'package:moonlight/features/wallet/presentation/pages/set_pin_page.dart';
import 'package:moonlight/features/wallet/presentation/pages/transaction_receipt_screen.dart';
import 'package:moonlight/features/wallet/presentation/pages/wallet_screen.dart';
import 'package:moonlight/features/withdrawal/data/datasources/withdrawal_remote_datasource.dart';
import 'package:moonlight/features/withdrawal/data/repositories/withdrawal_repository_impl.dart';
import 'package:moonlight/features/withdrawal/presentation/cubit/withdrawal_cubit.dart';
import 'package:http/http.dart' as http;
import 'package:moonlight/features/withdrawal/presentation/pages/withdrawal_page.dart';

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
        return MaterialPageRoute(builder: (context) => const AppShell());
      case RouteNames.debugScreen:
        return MaterialPageRoute(builder: (context) => const DebugScreen());

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

          try {
            return MaterialPageRoute(
              builder: (context) => MultiBlocProvider(
                providers: [
                  BlocProvider<ProfileCubit>(
                    create: (context) => sl<ProfileCubit>()..load(userUuid),
                  ),
                  BlocProvider<ChatCubit>(create: (context) => sl<ChatCubit>()),
                ],
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
              hostUuid: a['host_uuid'] as String,
              topic: a['topic'] as String,
              initialViewers: a['initial_viewers'] as int? ?? 0,
              startedAtIso:
                  a['started_at'] as String? ??
                  DateTime.now().toIso8601String(),
              avatarUrl: a['avatar_url'] as String?,
            ),
          ),
        );

      // In the RouteNames.liveViewer case in AppRouter:

      case RouteNames.liveViewer:
        {
          // Cast arguments properly with null safety
          final a = (settings.arguments as Map<String, dynamic>?) ?? {};

          // Add debug logging
          debugPrint('=== ROUTER DEBUG ===');
          debugPrint('Arguments received: $a');
          debugPrint('isPremium: ${a['isPremium']}');
          debugPrint('premiumFee: ${a['premiumFee']}');
          debugPrint('channel: ${a['channel']}');
          debugPrint('=====================');

          final id = a['id'] as int?;
          final uuid = a['uuid'] as String?;
          final channel = a['channel'] as String?;
          final hostUuid = a['hostUuid'] as String?;
          final isPremium = a['isPremium'] as int? ?? 0;
          final premiumFee = a['premiumFee'] as int? ?? 0;

          if (id == null || uuid == null || channel == null) {
            return MaterialPageRoute(
              builder: (context) => Scaffold(
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

          // Pass ALL arguments including premium info
          final routeArgs = {
            ...a,
            'id': id,
            'uuid': uuid,
            'channel': channel,
            'isPremium': isPremium,
            'premiumFee': premiumFee,
          };

          return MaterialPageRoute(
            builder: (context) => LiveViewerScreen.create(
              livestreamId: uuid,
              channelName: channel,
              hostUuid: hostUuid,
              hostInfo: host,
              startedAt: startedAt,
              routeArgs: routeArgs, // Pass all arguments
            ),
            settings: settings,
          );
        }
      // Optionally, add a new route for direct access to orchestrator
      // case RouteNames.liveViewerEnhanced:
      //   {
      //     final a = (settings.arguments as Map?) ?? {};
      //     final id = a['id'] as int?;
      //     final uuid = a['uuid'] as String?;
      //     final channel = a['channel'] as String?;
      //     final hostUuid = a['hostUuid'] as String?;

      //     if (id == null || uuid == null || channel == null) {
      //       return MaterialPageRoute(
      //         builder: (context) => Scaffold(
      //           body: Center(
      //             child: Text('Unable to open live (missing id/uuid/channel).'),
      //           ),
      //         ),
      //       );
      //     }

      //     final host = HostInfo(
      //       name: (a['hostName'] as String?) ?? 'Host',
      //       title: (a['title'] as String?) ?? 'Live',
      //       subtitle: '',
      //       badge: (a['role'] as String?) ?? 'Host',
      //       avatarUrl:
      //           (a['hostAvatar'] as String?) ??
      //           'https://via.placeholder.com/120x120.png?text=LIVE',
      //     );

      //     final startedAtIso = (a['startedAt'] as String?);
      //     final startedAt = startedAtIso == null
      //         ? null
      //         : DateTime.tryParse(startedAtIso);

      //     final repo = ViewerRepositoryImpl(
      //       http: GetIt.I<DioClient>(),
      //       pusher: GetIt.I<PusherService>(),
      //       authLocalDataSource: GetIt.I<AuthLocalDataSource>(),
      //       agoraViewerService: GetIt.I<AgoraViewerService>(),
      //       livestreamParam: uuid,
      //       livestreamIdNumeric: id,
      //       channelName: channel,
      //       hostUserUuid: hostUuid,
      //       initialHost: host,
      //       startedAt: startedAt,
      //     );

      //     return MaterialPageRoute(
      //       builder: (context) => LiveViewerOrchestrator(repository: repo),
      //       settings: settings,
      //     );
      //   }

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
      case RouteNames.giftCoins:
        return MaterialPageRoute(
          builder: (context) => BlocProvider<TransferCubit>(
            create: (context) => sl<TransferCubit>()..loadBalance(),
            child: const GiftCoinsPage(),
          ),
        );

      case RouteNames.notifications:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<NotificationsBloc>()..add(FetchNotifications()),
            child: const NotificationsScreen(),
          ),
        );

      case RouteNames.chat:
        {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return MaterialPageRoute(
              builder: (context) =>
                  Scaffold(body: Center(child: Text('Missing chat arguments'))),
            );
          }

          final conversation = args['conversation'] as ChatConversations;
          final isClub = args['isClub'] as bool? ?? false;
          final targetUserUuid = args['targetUserUuid'] as String?;

          return MaterialPageRoute(
            builder: (context) => AuthGuard(
              child: BlocProvider(
                // Add BlocProvider here
                create: (context) => GetIt.I<ChatCubit>(),
                child: ChatScreen(conversation: conversation, isClub: isClub),
              ),
            ),
          );
        }
      case RouteNames.conversations:
        return MaterialPageRoute(
          builder: (context) => AuthGuard(
            child: BlocProvider(
              // ← Add this BlocProvider wrapper
              create: (context) => sl<ChatCubit>(),
              child: ConversationsScreen(),
            ),
          ),
        );

      case RouteNames.clubs:
        return MaterialPageRoute(
          builder: (context) => AuthGuard(
            child: BlocProvider(
              create: (_) => sl<DiscoverClubsCubit>()..load(),
              child: const DiscoverClubsScreen(),
            ),
          ),
        );

      case RouteNames.clubProfile:
        final args = (settings.arguments as Map?) ?? {};
        final clubUuid = args['clubUuid'] as String?;

        if (clubUuid == null || clubUuid.isEmpty) {
          return MaterialPageRoute(
            builder: (context) => const Scaffold(
              body: Center(
                child: Text(
                  'Missing club identifier',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (context) => BlocProvider<ClubProfileCubit>(
            create: (_) => sl<ClubProfileCubit>()..load(clubUuid),
            child: const ClubProfileScreen(),
          ),
          settings: settings,
        );

      case RouteNames.wallet:
        return MaterialPageRoute(
          builder: (context) => BlocProvider<WalletCubit>(
            create: (context) => sl<WalletCubit>()..loadAll(),
            child: const WalletScreen(),
          ),
          settings: settings,
        );

      case RouteNames.createClub:
        return MaterialPageRoute(
          builder: (context) => AuthGuard(
            child: BlocProvider(
              create: (_) => sl<MyClubsCubit>(),
              child: const CreateClubScreen(),
            ),
          ),
          settings: settings,
        );

      case RouteNames.updateClub:
        final args = (settings.arguments as Map?) ?? {};
        final clubUuid = args['clubUuid'] as String?;

        if (clubUuid == null || clubUuid.isEmpty) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Missing club identifier')),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (_) => sl<EditClubCubit>(param1: clubUuid)..load(),
            child: EditClubScreen(clubUuid: clubUuid),
          ),
          settings: settings,
        );

      case RouteNames.clubMembers:
        final args = (settings.arguments as Map?) ?? {};
        final clubSlug = args['club'] as String?;
        final isAdmin = args['isAdmin'] as bool? ?? false;

        if (clubSlug == null || clubSlug.isEmpty) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Missing club identifier')),
            ),
          );
        }

        // Conditionally show admin or user version
        return MaterialPageRoute(
          builder: (context) => AuthGuard(
            child: BlocProvider(
              create: (_) => sl<ClubMembersCubit>(param1: clubSlug)..load(),
              child: isAdmin
                  ? ClubMembersPage(club: clubSlug) // Admin version
                  : ClubMembersPageUser(club: clubSlug), // User version
            ),
          ),
          settings: settings,
        );

      case RouteNames.supportClub:
        final args = settings.arguments as Map<String, dynamic>;

        final clubUuid = args['clubUuid'] as String?;
        if (clubUuid == null || clubUuid.isEmpty) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Missing club identifier')),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (context) => BlocProvider<DonateClubCubit>(
            create: (_) => sl<DonateClubCubit>(param1: clubUuid),
            child: SupportClubPage(
              clubName: args['clubName'],
              clubDescription: args['clubDescription'],
              clubAvatar: args['clubAvatar'],
            ),
          ),
          settings: settings,
        );

      case RouteNames.buyCoins:
        // Reuse the same cubit instance if navigating from Wallet.
        // If you want an independent instance, use create: (_) => sl<WalletCubit>() instead.
        return MaterialPageRoute(
          builder: (context) => BlocProvider.value(
            value: sl<WalletCubit>(),
            child: const BuyCoinsScreen(),
          ),
          settings: settings,
        );

      case RouteNames.transactionReceipt:
        return MaterialPageRoute(
          builder: (context) => const TransactionReceiptScreen(),
          settings: settings,
        );

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

      case RouteNames.withdrawal:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<WithdrawalCubit>(), // Get from GetIt
            child: const WithdrawalPage(),
          ),
        );

      // case RouteNames.setPin:
      //   return MaterialPageRoute(builder: (context) => const SetPinPage());

      case RouteNames.blockedUsers:
        return MaterialPageRoute(
          builder: (context) => const BlockedUsersPage(),
        );

      case RouteNames.changeEmail:
        return MaterialPageRoute(builder: (context) => const ChangeEmailPage());

      case RouteNames.changeUsername:
        return MaterialPageRoute(
          builder: (context) => const ChangeUsernamePage(),
        );

      case RouteNames.setNewPin:
        return MaterialPageRoute(builder: (context) => const SetNewPinPage());

      case RouteNames.resetPin:
        return MaterialPageRoute(builder: (context) => const ResetPinPage());

      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
