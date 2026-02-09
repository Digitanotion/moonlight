// // lib/core/injection_container.dart
// import 'dart:async';

// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:get_it/get_it.dart';
// import 'package:moonlight/core/config/runtime_config_cache.dart';
// import 'package:moonlight/core/network/interceptors/auth_interceptor.dart';
// import 'package:moonlight/core/network/interceptors/cache_interceptor.dart';
// import 'package:moonlight/core/network/interceptors/dio_extra_hook.dart';
// import 'package:moonlight/core/network/interceptors/error_normalizer_interceptor.dart';
// import 'package:moonlight/core/network/interceptors/idempotency_interceptor.dart';
// import 'package:moonlight/core/network/interceptors/request_id_interceptor.dart';
// import 'package:moonlight/core/network/interceptors/retry_interceptor.dart';
// import 'package:moonlight/core/services/agora_viewer_service.dart';
// import 'package:moonlight/core/services/current_user_service.dart';
// import 'package:moonlight/core/services/host_pusher_service.dart';
// import 'package:moonlight/core/services/like_memory.dart';
// import 'package:moonlight/core/services/realtime_unread_service.dart';
// import 'package:moonlight/core/services/runtime_config_refresh_service.dart';
// import 'package:moonlight/core/services/unread_badge_service.dart';
// import 'package:moonlight/features/chat/data/repositories/chat_repository_impl.dart';
// import 'package:moonlight/features/chat/data/services/chat_api_service.dart';
// import 'package:moonlight/features/chat/domain/repositories/chat_repository.dart';
// import 'package:moonlight/features/chat/presentation/pages/cubit/chat_cubit.dart';
// import 'package:moonlight/features/clubs/data/datasources/club_income_remote_data_source.dart';
// import 'package:moonlight/features/clubs/data/datasources/clubs_remote_data_source.dart';
// import 'package:moonlight/features/clubs/data/repositories/club_income_repository_impl.dart';
// import 'package:moonlight/features/clubs/data/repositories/clubs_repository_impl.dart';
// import 'package:moonlight/features/clubs/domain/repositories/club_income_repository.dart';
// import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
// import 'package:moonlight/features/clubs/presentation/cubit/club_income_cubit.dart';
// import 'package:moonlight/features/clubs/presentation/cubit/club_members_cubit.dart';
// import 'package:moonlight/features/clubs/presentation/cubit/club_profile_cubit.dart';
// import 'package:moonlight/features/clubs/presentation/cubit/create_club_cubit.dart';
// import 'package:moonlight/features/clubs/presentation/cubit/discover_clubs_cubit.dart';
// import 'package:moonlight/features/clubs/presentation/cubit/donate_club_cubit.dart';
// import 'package:moonlight/features/clubs/presentation/cubit/edit_club_cubit.dart';
// import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart'
//     show MyClubsCubit;
// import 'package:moonlight/features/clubs/presentation/cubit/suggested_clubs_cubit.dart';
// import 'package:moonlight/features/create_post/data/datasources/create_post_remote_datasource.dart';
// import 'package:moonlight/features/create_post/data/repositories/create_post_repository_impl.dart';
// import 'package:moonlight/features/create_post/domain/repositories/create_post_repository.dart';
// import 'package:moonlight/features/create_post/presentation/cubit/create_post_cubit.dart';
// import 'package:moonlight/features/feed/data/datasources/feed_remote_datasource.dart';
// import 'package:moonlight/features/feed/data/repositories/feed_repository_impl.dart';
// import 'package:moonlight/features/feed/domain/repositories/feed_repository.dart';
// import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
// import 'package:moonlight/features/gift_coins/data/datasources/gift_local_datasource.dart';
// import 'package:moonlight/features/gift_coins/data/datasources/gift_remote_datasource.dart';
// import 'package:moonlight/features/gift_coins/data/repositories/gift_repository_impl.dart';
// import 'package:moonlight/features/gift_coins/domain/repositories/gift_repository.dart';
// import 'package:moonlight/features/gift_coins/presentation/cubit/transfer_cubit.dart';
// import 'package:moonlight/features/home/data/datasources/live_feed_remote_datasource.dart';
// import 'package:moonlight/features/home/data/repositories/live_feed_repository_impl.dart';
// import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
// import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_bloc.dart';
// import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
// import 'package:moonlight/features/live_viewer/domain/entities.dart';
// import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
// import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';
// import 'package:moonlight/features/live_viewer/presentation/services/network_monitor_service.dart';
// import 'package:moonlight/features/live_viewer/presentation/services/reconnection_service.dart';
// import 'package:moonlight/features/live_viewer/presentation/services/role_change_service.dart';
// import 'package:moonlight/features/livestream/data/repositories/participants_repository_impl.dart';
// import 'package:moonlight/features/livestream/domain/repositories/participants_repository.dart';
// import 'package:moonlight/features/livestream/presentation/bloc/participants_bloc.dart';
// import 'package:moonlight/features/notifications/data/datasources/notifications_remote_data_source.dart';
// import 'package:moonlight/features/notifications/data/repositories/notifications_repository.dart';
// import 'package:moonlight/features/notifications/presentation/bloc/notifications_bloc.dart';
// import 'package:moonlight/features/post_view/data/datasources/post_remote_datasource.dart';
// import 'package:moonlight/features/post_view/data/repositories/post_repository_impl.dart';
// import 'package:moonlight/features/post_view/domain/repositories/post_repository.dart';
// import 'package:moonlight/features/post_view/presentation/cubit/post_cubit.dart';
// import 'package:moonlight/features/profile_view/presentation/cubit/profile_cubit.dart';
// import 'package:moonlight/features/settings/data/datasources/blocked_users_remote_datasource.dart';
// import 'package:moonlight/features/settings/data/datasources/change_email_remote_datasource.dart';
// import 'package:moonlight/features/settings/data/datasources/change_username_remote_datasource.dart';
// import 'package:moonlight/features/settings/data/repositories/blocked_users_repository_impl.dart';
// import 'package:moonlight/features/settings/data/repositories/change_email_repository_impl.dart';
// import 'package:moonlight/features/settings/data/repositories/change_username_repository_impl.dart';
// import 'package:moonlight/features/settings/domain/repositories/blocked_users_repository.dart';
// import 'package:moonlight/features/settings/domain/repositories/change_email_repository.dart';
// import 'package:moonlight/features/settings/domain/repositories/change_username_repository.dart';
// import 'package:moonlight/features/settings/domain/usecases/get_notification_settings.dart';
// import 'package:moonlight/features/settings/domain/usecases/update_notification_settings.dart';
// import 'package:moonlight/features/settings/presentation/cubit/blocked_users_cubit.dart';
// import 'package:moonlight/features/settings/presentation/cubit/change_email_cubit.dart';
// import 'package:moonlight/features/settings/presentation/cubit/change_username_cubit.dart';
// import 'package:moonlight/features/wallet/data/datasources/local_wallet_datasource.dart';
// import 'package:moonlight/features/wallet/data/datasources/pin_remote_datasource.dart';
// import 'package:moonlight/features/wallet/data/datasources/remote_wallet_datasource.dart';
// import 'package:moonlight/features/wallet/data/repositories/pin_repository_impl.dart';
// import 'package:moonlight/features/wallet/data/repositories/wallet_repository_impl.dart';
// import 'package:moonlight/features/wallet/domain/repositories/pin_repository.dart';
// import 'package:moonlight/features/wallet/domain/repositories/wallet_repository.dart';
// import 'package:moonlight/features/wallet/domain/usecases/set_pin.dart';
// import 'package:moonlight/features/wallet/presentation/cubit/reset_pin_cubit.dart';
// import 'package:moonlight/features/wallet/presentation/cubit/set_new_pin_cubit.dart';
// import 'package:moonlight/features/wallet/presentation/cubit/set_pin_cubit.dart';
// import 'package:moonlight/features/wallet/presentation/cubit/wallet_cubit.dart';
// import 'package:moonlight/features/wallet/services/idempotency_helper.dart';
// import 'package:moonlight/features/wallet/services/play_billing_service.dart';
// import 'package:moonlight/features/withdrawal/data/datasources/withdrawal_remote_datasource.dart';
// import 'package:moonlight/features/withdrawal/data/repositories/withdrawal_repository_impl.dart';
// import 'package:moonlight/features/withdrawal/domain/repositories/withdrawal_repository.dart';
// import 'package:moonlight/features/withdrawal/presentation/cubit/withdrawal_cubit.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import 'package:moonlight/core/config/runtime_config.dart';
// import 'package:moonlight/core/network/dio_client.dart';
// import 'package:moonlight/core/services/agora_service.dart';
// import 'package:moonlight/core/services/pusher_service.dart';

// import 'package:moonlight/core/services/google_signin_service.dart';
// // ✅ Profile View
// import 'package:moonlight/features/profile_view/data/datasources/profile_remote_datasource.dart'
//     as view_ds;
// import 'package:moonlight/features/profile_view/data/repositories/profile_repository_impl.dart'
//     as view_repo_impl;
// import 'package:moonlight/features/profile_view/domain/repositories/profile_repository.dart'
//     as view_repo;
// import 'package:moonlight/features/profile_view/presentation/cubit/profile_cubit.dart';

// // AUTH
// import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
// import 'package:moonlight/features/auth/data/datasources/auth_remote_datasource.dart';
// import 'package:moonlight/features/auth/data/repositories/auth_repository_impl.dart';
// import 'package:moonlight/features/auth/domain/repositories/auth_repository.dart';
// import 'package:moonlight/features/auth/domain/usecases/get_current_user.dart';
// import 'package:moonlight/features/auth/domain/usecases/check_auth_status.dart'
//     hide Logout;
// import 'package:moonlight/features/auth/domain/usecases/logout.dart';
// import 'package:moonlight/features/auth/domain/usecases/login_with_email.dart';
// import 'package:moonlight/features/auth/domain/usecases/sign_up_with_email.dart';
// import 'package:moonlight/features/auth/domain/usecases/social_login.dart';
// import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';

// // ONBOARDING
// import 'package:moonlight/features/onboarding/data/datasources/onboarding_local_datasource.dart';
// import 'package:moonlight/features/onboarding/data/repositories/onboarding_repository_impl.dart';
// import 'package:moonlight/features/onboarding/domain/repositories/onboarding_repository.dart';
// import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';

// // SEARCH
// import 'package:moonlight/features/search/data/datasources/search_remote_data_source.dart';
// import 'package:moonlight/features/search/data/repositories/search_repository_impl.dart';
// import 'package:moonlight/features/search/domain/repositories/search_repository.dart';
// import 'package:moonlight/features/search/domain/usecases/get_popular_clubs.dart';
// import 'package:moonlight/features/search/domain/usecases/get_suggested_users.dart';
// import 'package:moonlight/features/search/domain/usecases/get_trending_tags.dart';
// import 'package:moonlight/features/search/domain/usecases/search_content.dart';
// import 'package:moonlight/features/search/presentation/bloc/search_bloc.dart';

// // PROFILE/SETTINGS
// import 'package:moonlight/features/profile_setup/data/datasources/country_local_data_source.dart';
// import 'package:moonlight/features/profile_setup/data/datasources/profile_remote_data_source.dart';
// import 'package:moonlight/features/profile_setup/data/repositories/profile_repository_impl.dart';
// import 'package:moonlight/features/profile_setup/domain/repositories/profile_repository.dart';
// import 'package:moonlight/features/profile_setup/domain/usecases/fetch_my_profile.dart';
// import 'package:moonlight/features/profile_setup/domain/usecases/setup_profile.dart';
// import 'package:moonlight/features/profile_setup/domain/usecases/update_interests.dart';
// import 'package:moonlight/features/profile_setup/domain/usecases/update_profile.dart';
// import 'package:moonlight/features/profile_setup/presentation/cubit/profile_page_cubit.dart';
// import 'package:moonlight/features/profile_setup/presentation/cubit/profile_setup_cubit.dart';
// import 'package:moonlight/features/edit_profile/presentation/cubit/edit_profile_cubit.dart';
// import 'package:moonlight/features/settings/data/datasources/account_remote_data_source.dart';
// import 'package:moonlight/features/settings/data/repositories/account_repository_impl.dart';
// import 'package:moonlight/features/settings/domain/repositories/account_repository.dart';
// import 'package:moonlight/features/settings/domain/usecases/deactivate_account.dart';
// import 'package:moonlight/features/settings/domain/usecases/delete_account.dart';
// import 'package:moonlight/features/settings/domain/usecases/reactivate_account.dart';
// import 'package:moonlight/features/settings/presentation/cubit/account_settings_cubit.dart';
// import 'package:moonlight/features/user_interest/presentation/cubit/user_interest_cubit.dart';

// // LIVE
// import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_mock.dart';
// import 'package:moonlight/features/live_viewer/domain/repositories/viewer_repository.dart';
// import 'package:moonlight/features/livestream/data/repositories/go_live_repository_impl.dart';
// import 'package:moonlight/features/livestream/domain/repositories/go_live_repository.dart';
// import 'package:moonlight/features/livestream/data/repositories/live_session_repository_impl.dart';
// import 'package:moonlight/features/livestream/domain/repositories/live_session_repository.dart';
// import 'package:moonlight/features/livestream/data/services/audio_test_service_impl.dart';
// import 'package:moonlight/features/livestream/data/services/camera_service_impl.dart';
// import 'package:moonlight/features/livestream/domain/services/audio_test_service.dart';
// import 'package:moonlight/features/livestream/domain/services/camera_service.dart';
// import 'package:moonlight/features/livestream/domain/session/live_session_tracker.dart';
// import 'package:moonlight/features/livestream/presentation/bloc/live_host_bloc.dart';
// import 'package:moonlight/features/livestream/presentation/cubits/go_live_cubit.dart';

// final sl = GetIt.instance;

// /// Used ONLY to bootstrap `/api/config` before we know the real base URL.
// /// Must be your final host (no trailing slash).
// const _fallbackHost = 'https://svc.moonlightstream.app';

// // ======= SPLASH OPTIMIZER (CRITICAL: REPLACE YOUR CURRENT ONE) =======
// class SplashOptimizer {
//   static final Completer<void> _essentialsLoaded = Completer<void>();
//   static bool _isInitializing = false;
//   static bool _isBackgroundLoadingStarted = false;

//   static Future<void> loadEssentialsOnly() async {
//     if (_isInitializing) {
//       return _essentialsLoaded.future;
//     }

//     _isInitializing = true;
//     debugPrint('🚀 [SPLASH] Loading essential dependencies only...');

//     try {
//       // --------- Core essentials ONLY ---------
//       final prefs = await SharedPreferences.getInstance();
//       sl.registerLazySingleton<SharedPreferences>(() => prefs);

//       // Device info (lightweight)
//       sl.registerLazySingleton<DeviceInfoPlugin>(() => DeviceInfoPlugin());

//       // --------- Bootstrap RuntimeConfig ---------
//       debugPrint('🔄 [SPLASH] Loading RuntimeConfig...');

//       RuntimeConfig cfg;
//       try {
//         // Try to load from environment or your config service
//         cfg = await _loadRuntimeConfig();
//       } catch (e) {
//         debugPrint('⚠️ [SPLASH] RuntimeConfig fallback: $e');
//         cfg = RuntimeConfig(
//           agoraAppId: '',
//           apiBaseUrl: _fallbackHost,
//           pusherKey: '', // This is why it's empty!
//           pusherCluster: 'mt1',
//         );
//       }

//       sl.registerLazySingleton<RuntimeConfig>(() => cfg);

//       // Auth essentials
//       sl.registerLazySingleton<AuthLocalDataSource>(
//         () => AuthLocalDataSourceImpl(sharedPreferences: prefs),
//       );

//       // Minimal Dio client for auth (WITHOUT heavy interceptors)
//       final basicDio = Dio(
//         BaseOptions(
//           baseUrl: cfg.apiBaseUrl,
//           connectTimeout: const Duration(seconds: 8),
//           receiveTimeout: const Duration(seconds: 8),
//           headers: {'Accept': 'application/json'},
//         ),
//       );

//       // Simple auth interceptor ONLY
//       basicDio.interceptors.add(
//         InterceptorsWrapper(
//           onRequest: (options, handler) async {
//             final token = await sl<AuthLocalDataSource>().readToken();
//             if (token != null && token.isNotEmpty) {
//               options.headers['Authorization'] = 'Bearer $token';
//             }
//             handler.next(options);
//           },
//         ),
//       );

//       sl.registerLazySingleton<Dio>(() => basicDio, instanceName: 'authDio');

//       // Essential repositories for auth
//       sl.registerLazySingleton<AuthRemoteDataSource>(
//         () => AuthRemoteDataSourceImpl(
//           client: sl<Dio>(instanceName: 'authDio'),
//           prefs: prefs,
//         ),
//       );

//       sl.registerLazySingleton<AuthRepository>(
//         () => AuthRepositoryImpl(
//           localDataSource: sl(),
//           remoteDataSource: sl(),
//           deviceInfo: sl(),
//           googleSignInService: GoogleSignInService(),
//         ),
//       );

//       // Essential use cases
//       sl.registerLazySingleton<GetCurrentUser>(() => GetCurrentUser(sl()));
//       sl.registerLazySingleton<CheckAuthStatus>(() => CheckAuthStatus(sl()));
//       sl.registerLazySingleton<Logout>(() => Logout(sl()));
//       sl.registerLazySingleton<LoginWithEmail>(() => LoginWithEmail(sl()));
//       sl.registerLazySingleton<SignUpWithEmail>(() => SignUpWithEmail(sl()));
//       sl.registerLazySingleton<SocialLogin>(() => SocialLogin(sl()));

//       // Onboarding essentials
//       sl.registerLazySingleton<OnboardingLocalDataSource>(
//         () => OnboardingLocalDataSourceImpl(sharedPreferences: sl()),
//       );

//       sl.registerLazySingleton<OnboardingRepository>(
//         () => OnboardingRepositoryImpl(localDataSource: sl()),
//       );

//       // Current user service
//       sl.registerLazySingleton(() => CurrentUserService());

//       // Essential blocs (register but don't create yet)
//       sl.registerFactory<OnboardingBloc>(
//         () => OnboardingBloc(repository: sl()),
//       );

//       sl.registerFactory<AuthBloc>(
//         () => AuthBloc(
//           loginWithEmail: sl(),
//           signUpWithEmail: sl(),
//           socialLogin: sl(),
//           checkAuthStatusUseCase: sl(),
//           logout: sl(),
//           getCurrentUser: sl(),
//           authRepository: sl(),
//           currentUserService: sl(),
//         ),
//       );

//       debugPrint('✅ [SPLASH] Essential dependencies loaded');
//       _essentialsLoaded.complete();
//     } catch (e, stack) {
//       debugPrint('❌ [SPLASH] Error loading essentials: $e');
//       debugPrint('Stack: $stack');
//       _essentialsLoaded.completeError(e);
//       rethrow;
//     }
//   }

//   static Future<void> loadRemainingDependencies() async {
//     if (_isBackgroundLoadingStarted) {
//       debugPrint('⚠️ [BACKGROUND] Already loading remaining dependencies');
//       return;
//     }

//     _isBackgroundLoadingStarted = true;
//     debugPrint('🔄 [BACKGROUND] Loading remaining dependencies...');

//     try {
//       // Wait for essentials to be ready
//       await _essentialsLoaded.future;

//       // Initialize the rest of the app
//       await initRemainingDependencies();

//       debugPrint('✅ [BACKGROUND] All dependencies loaded successfully');
//     } catch (e) {
//       debugPrint('⚠️ [BACKGROUND] Error loading remaining dependencies: $e');
//       // Don't crash the app
//     }
//   }

//   static Future<RuntimeConfig> reloadRuntimeConfig() async {
//     debugPrint('🔄 [SPLASH] Reloading RuntimeConfig from server...');
//     try {
//       final cfg = await _loadRuntimeConfig();

//       // Update GetIt with the new config
//       if (sl.isRegistered<RuntimeConfig>()) {
//         sl.unregister<RuntimeConfig>();
//       }
//       sl.registerLazySingleton<RuntimeConfig>(() => cfg);

//       debugPrint('✅ [SPLASH] RuntimeConfig reloaded successfully');
//       debugPrint('   Pusher Key: ${cfg.pusherKey.isEmpty ? "EMPTY" : "SET"}');

//       return cfg;
//     } catch (e, stack) {
//       debugPrint('❌ [SPLASH] Failed to reload RuntimeConfig: $e');
//       debugPrint('Stack: $stack');
//       rethrow;
//     }
//   }
// }

// // In _loadRuntimeConfig() - ADD debug logging:
// Future<RuntimeConfig> _loadRuntimeConfig() async {
//   debugPrint('🔧 Loading RuntimeConfig with caching...');

//   final prefs = await SharedPreferences.getInstance();
//   final cache = RuntimeConfigCache(prefs);

//   return await cache.loadWithCache(
//     fetchFresh: () async {
//       debugPrint('🌐 Fetching RuntimeConfig from server...');

//       final bootstrapDio = Dio(
//         BaseOptions(
//           baseUrl: '$_fallbackHost/api',
//           connectTimeout: const Duration(seconds: 8), // Reduced timeout
//           receiveTimeout: const Duration(seconds: 8),
//         ),
//       );

//       try {
//         final response = await bootstrapDio.get('/v1/config');
//         final data = response.data as Map<String, dynamic>;

//         debugPrint('📋 Config response keys: ${data.keys.toList()}');

//         final cfg = RuntimeConfig(
//           agoraAppId:
//               data['agora_app_id'] ??
//               const String.fromEnvironment('AGORA_APP_ID', defaultValue: ''),
//           apiBaseUrl: data['api_base_url'] ?? _fallbackHost,
//           pusherKey:
//               data['pusher_key'] ??
//               const String.fromEnvironment('PUSHER_KEY', defaultValue: ''),
//           pusherCluster:
//               data['pusher_cluster'] ??
//               const String.fromEnvironment(
//                 'PUSHER_CLUSTER',
//                 defaultValue: 'mt1',
//               ),
//         );

//         debugPrint('✅ RuntimeConfig fetched from server:');
//         debugPrint('   API Base URL: ${cfg.apiBaseUrl}');
//         debugPrint('   Pusher Key: ${cfg.pusherKey.isEmpty ? "EMPTY" : "SET"}');
//         debugPrint('   Pusher Cluster: ${cfg.pusherCluster}');

//         return cfg;
//       } catch (e) {
//         debugPrint('❌ Failed to load config from API: $e');

//         // Fallback to environment variables
//         final envCfg = RuntimeConfig(
//           agoraAppId: const String.fromEnvironment(
//             'AGORA_APP_ID',
//             defaultValue: '',
//           ),
//           apiBaseUrl: _fallbackHost,
//           pusherKey: const String.fromEnvironment(
//             'PUSHER_KEY',
//             defaultValue: '',
//           ),
//           pusherCluster: const String.fromEnvironment(
//             'PUSHER_CLUSTER',
//             defaultValue: 'mt1',
//           ),
//         );

//         debugPrint('⚠️ Using environment config:');
//         debugPrint(
//           '   Pusher Key from env: ${envCfg.pusherKey.isEmpty ? "EMPTY" : "SET"}',
//         );

//         return envCfg;
//       }
//     },
//     forceRefresh: false,
//   );
// }

// void _initializeLiveViewerServices() {
//   debugPrint('🔧 Initializing Live Viewer Services...');

//   // Register AgoraViewerService
//   // sl.registerLazySingleton<AgoraViewerService>(() {
//   //   return AgoraViewerService(
//   //     onTokenRefresh: (role) async {
//   //       // Get current livestream ID from somewhere - you'll need to pass this
//   //       final livestreamId = ''; // You need to get this dynamically
//   //       final token = await sl<AuthLocalDataSource>().readToken();
//   //       final dio = sl<Dio>(instanceName: 'mainDio');

//   //       final response = await dio.get(
//   //         '/api/v1/live/$livestreamId/rtc',
//   //         queryParameters: {'role': role},
//   //         options: Options(headers: {'Authorization': 'Bearer $token'}),
//   //       );

//   //       final data = response.data as Map<String, dynamic>;
//   //       return data['rtc_token'] as String;
//   //     },
//   //   );
//   // });

//   // Register AgoraViewerService with PROPER token refresh
//   sl.registerLazySingleton<AgoraViewerService>(() {
//     debugPrint('🎯 Creating AgoraViewerService instance');

//     return AgoraViewerService(
//       onTokenRefresh: (role) async {
//         debugPrint('🔄 Token refresh requested for role: $role');

//         // We can't know livestreamId here - this is a design flaw
//         // For now, we'll need to fetch a new token differently
//         // Let's create a simple token refresh that uses current channel
//         try {
//           final agoraService = sl<AgoraViewerService>();
//           final currentChannel = agoraService.channelId;

//           if (currentChannel == null || currentChannel.isEmpty) {
//             throw Exception('No current channel to refresh token for');
//           }

//           // Extract livestream ID from channel name
//           // Assuming channel format: "live_abc123" or similar
//           final channelPrefix = 'live_';
//           String? livestreamId;

//           if (currentChannel.startsWith(channelPrefix)) {
//             // If channel is like "live_abc123", we need the actual livestream ID
//             // This is a hack - you need to store livestream ID somewhere
//             debugPrint(
//               '⚠️ Need livestream ID for token refresh, using channel: $currentChannel',
//             );

//             // For testing, just get a fresh token from server
//             final authLocal = sl<AuthLocalDataSource>();
//             final token = await authLocal.readToken();
//             final dio = sl<Dio>(instanceName: 'mainDio');

//             // Call a generic token refresh endpoint
//             final response = await dio.post(
//               '/api/v1/live/refresh-token',
//               data: {'role': role, 'channel': currentChannel},
//               options: Options(headers: {'Authorization': 'Bearer $token'}),
//             );

//             final data = response.data as Map<String, dynamic>;
//             return data['token'] as String;
//           } else {
//             throw Exception(
//               'Cannot determine livestream ID from channel: $currentChannel',
//             );
//           }
//         } catch (e) {
//           debugPrint('❌ Token refresh failed: $e');
//           // For now, return empty string so at least the service initializes
//           return '';
//         }
//       },
//     );
//   });

//   // Register LiveStreamService
//   sl.registerLazySingleton<LiveStreamService>(() {
//     return LiveStreamService(
//       agoraService: sl<AgoraViewerService>(),
//       tokenRefresher: sl<AgoraViewerService>().onTokenRefresh,
//     );
//   });

//   // Register NetworkMonitorService
//   sl.registerLazySingleton<NetworkMonitorService>(() {
//     return NetworkMonitorService(sl<LiveStreamService>());
//   });

//   // Register ReconnectionService
//   sl.registerLazySingleton<ReconnectionService>(() {
//     return ReconnectionService(sl<LiveStreamService>());
//   });

//   // Register RoleChangeService
//   sl.registerLazySingleton<RoleChangeService>(() {
//     return RoleChangeService(sl<LiveStreamService>());
//   });

//   // Register ViewerBloc factory with services
//   sl.registerFactoryParam<ViewerBloc, ViewerRepositoryImpl, void>((repo, _) {
//     return ViewerBloc(
//       repo,
//       liveStreamService: sl<LiveStreamService>(),
//       agoraViewerService: sl<AgoraViewerService>(),
//       networkMonitorService: sl<NetworkMonitorService>(),
//       reconnectionService: sl<ReconnectionService>(),
//       roleChangeService: sl<RoleChangeService>(),
//     );
//   });

//   debugPrint('✅ Live Viewer Services initialized');
// }

// ViewerRepositoryImpl createViewerRepository({
//   required String livestreamParam,
//   required int livestreamIdNumeric,
//   required String channelName,
//   String? hostUserUuid,
//   HostInfo? initialHost,
//   DateTime? startedAt,
// }) {
//   return ViewerRepositoryImpl(
//     http: sl<DioClient>(),
//     pusher: sl<PusherService>(),
//     authLocalDataSource: sl<AuthLocalDataSource>(),
//     agoraViewerService: sl<AgoraViewerService>(), // Important!
//     livestreamParam: livestreamParam,
//     livestreamIdNumeric: livestreamIdNumeric,
//     channelName: channelName,
//     hostUserUuid: hostUserUuid,
//     initialHost: initialHost,
//     startedAt: startedAt,
//   );
// }

// // ======= MAIN INITIALIZATION (RUNS IN BACKGROUND) =======
// Future<void> initRemainingDependencies() async {
//   debugPrint('🏗️ [INIT] Starting full dependency initialization...');

//   final prefs = sl<SharedPreferences>();
//   final cfg = sl<RuntimeConfig>();

//   // --------- Create main DioClient ---------
//   final dioClient = DioClient(cfg.apiBaseUrl, sl<AuthLocalDataSource>());
//   sl.registerLazySingleton<DioClient>(() => dioClient);

//   // Register the Dio from DioClient as the main instance
//   sl.registerLazySingleton<Dio>(() => dioClient.dio, instanceName: 'mainDio');

//   // Attach interceptors to the main Dio instance
//   final mainDio = sl<Dio>(instanceName: 'mainDio');

//   // Register and attach interceptors
//   sl.registerFactory<RequestIdInterceptor>(() => RequestIdInterceptor());
//   sl.registerFactory<IdempotencyInterceptor>(
//     () => IdempotencyInterceptor(prefs),
//   );
//   sl.registerFactory<ErrorNormalizerInterceptor>(
//     () => ErrorNormalizerInterceptor(),
//   );
//   sl.registerFactory<RetryInterceptor>(() => RetryInterceptor(maxRetries: 3));
//   sl.registerFactory<AuthInterceptor>(
//     () =>
//         AuthInterceptor(sl<AuthLocalDataSource>(), sl<AuthRemoteDataSource>()),
//   );
//   sl.registerFactory<DioExtraHook>(() => DioExtraHook(mainDio));

//   // Attach interceptors in order
//   mainDio.interceptors.add(sl<DioExtraHook>());
//   mainDio.interceptors.add(sl<RequestIdInterceptor>());
//   mainDio.interceptors.add(sl<AuthInterceptor>());
//   mainDio.interceptors.add(sl<IdempotencyInterceptor>());
//   mainDio.interceptors.add(sl<ErrorNormalizerInterceptor>());
//   mainDio.interceptors.add(sl<RetryInterceptor>());

//   // --------- Register remaining data sources ---------
//   sl.registerLazySingleton<ProfileRemoteDataSource>(
//     () => ProfileRemoteDataSourceImpl(sl<Dio>(instanceName: 'mainDio')),
//   );
//   sl.registerLazySingleton<CountryLocalDataSource>(
//     () => CountryLocalDataSourceImpl(),
//   );
//   sl.registerLazySingleton<AccountRemoteDataSource>(
//     () => AccountRemoteDataSourceImpl(sl<Dio>(instanceName: 'mainDio')),
//   );
//   sl.registerLazySingleton<SearchRemoteDataSource>(
//     () => SearchRemoteDataSourceImpl(sl<DioClient>()),
//   );
//   sl.registerLazySingleton<NotificationsRemoteDataSource>(
//     () => NotificationsRemoteDataSource(sl<DioClient>()),
//   );

//   // --------- Register remaining repositories ---------
//   sl.registerLazySingleton<AccountRepository>(
//     () => AccountRepositoryImpl(sl<AccountRemoteDataSource>()), // ✅
//   );

//   // Register the new usecases
//   sl.registerLazySingleton(() => UpdateNotificationSettings(sl()));
//   sl.registerLazySingleton(() => GetNotificationSettings(sl()));

//   // Register AccountSettingsCubit as a factory
//   sl.registerFactory<AccountSettingsCubit>(() {
//     return AccountSettingsCubit(
//       repository: sl<AccountRepository>(), // ✅ Direct repository
//       prefs: sl<SharedPreferences>(),
//     );
//   });

//   sl.registerLazySingleton<SearchRepository>(
//     () => SearchRepositoryImpl(remoteDataSource: sl()),
//   );
//   sl.registerLazySingleton<ProfileRepository>(
//     () => ProfileRepositoryImpl(
//       remote: sl(),
//       countryLocal: sl(),
//       local: sl<AuthLocalDataSource>(),
//     ),
//   );
//   sl.registerLazySingleton<NotificationsRepository>(
//     () => NotificationsRepositoryImpl(sl<NotificationsRemoteDataSource>()),
//   );

//   // --------- Register remaining use cases ---------
//   sl.registerLazySingleton(() => DeactivateAccount(sl()));
//   sl.registerLazySingleton(() => ReactivateAccount(sl()));
//   sl.registerLazySingleton(() => DeleteAccount(sl()));
//   sl.registerLazySingleton<SearchContent>(() => SearchContent(sl()));
//   sl.registerLazySingleton<GetTrendingTags>(() => GetTrendingTags(sl()));
//   sl.registerLazySingleton<GetSuggestedUsers>(() => GetSuggestedUsers(sl()));
//   sl.registerLazySingleton<GetPopularClubs>(() => GetPopularClubs(sl()));
//   sl.registerLazySingleton(() => SetupProfile(sl()));
//   sl.registerLazySingleton(() => UpdateInterests(sl()));
//   sl.registerLazySingleton(() => UpdateProfile(sl()));
//   sl.registerLazySingleton(() => FetchMyProfile(sl()));

//   // --------- Register remaining blocs/cubits ---------
//   sl.registerFactory<SearchBloc>(
//     () => SearchBloc(
//       searchContent: sl(),
//       getTrendingTags: sl(),
//       getSuggestedUsers: sl(),
//       getPopularClubs: sl(),
//     ),
//   );
//   sl.registerFactory<NotificationsBloc>(
//     () => NotificationsBloc(sl<NotificationsRepository>()),
//   );
//   sl.registerFactory(() => ProfileSetupCubit(sl(), sl()));
//   sl.registerFactory(() => UserInterestCubit(sl()));

//   // Settings DataSources
//   sl.registerLazySingleton<BlockedUsersRemoteDataSource>(
//     () => BlockedUsersRemoteDataSource(sl<DioClient>()),
//   );

//   sl.registerLazySingleton<ChangeEmailRemoteDataSource>(
//     () => ChangeEmailRemoteDataSource(sl<DioClient>()),
//   );

//   // sl.registerFactory<ChangeEmailCubit>(
//   //   () => ChangeEmailCubit(sl<ChangeEmailRepository>()),
//   // );

//   sl.registerLazySingleton<ChangeUsernameRemoteDataSource>(
//     () => ChangeUsernameRemoteDataSource(sl<DioClient>()),
//   );

//   // Settings Repositories
//   sl.registerLazySingleton<BlockedUsersRepository>(
//     () => BlockedUsersRepositoryImpl(sl<BlockedUsersRemoteDataSource>()),
//   );

//   sl.registerLazySingleton<ChangeEmailRepository>(
//     () => ChangeEmailRepositoryImpl(sl<ChangeEmailRemoteDataSource>()),
//   );

//   sl.registerLazySingleton<ChangeUsernameRepository>(
//     () => ChangeUsernameRepositoryImpl(sl<ChangeUsernameRemoteDataSource>()),
//   );

//   // Update the cubit registrations to use repositories
//   sl.registerFactory<BlockedUsersCubit>(
//     () => BlockedUsersCubit(sl<BlockedUsersRepository>()),
//   );

//   sl.registerFactory<ChangeEmailCubit>(
//     () => ChangeEmailCubit(sl<ChangeEmailRepository>()),
//   );

//   sl.registerFactory<ChangeUsernameCubit>(
//     () => ChangeUsernameCubit(sl<ChangeUsernameRepository>()),
//   );

//   // Wallet cubits
//   sl.registerFactory(() => ResetPinCubit(sl<PinRepository>()));
//   // ADD SetNewPinCubit registration
//   sl.registerFactory<SetNewPinCubit>(() => SetNewPinCubit(sl<PinRepository>()));
//   // ======= END OF NEW CUBITS =======

//   sl.registerFactory(
//     () => ProfilePageCubit(
//       fetchMyProfile: sl(),
//       fetchMyPosts:
//           ({required String userUuid, int page = 1, int perPage = 50}) async {
//             final paginated = await sl<view_repo.ProfileRepository>()
//                 .getUserPosts(userUuid, page: page, perPage: perPage);
//             return paginated.data;
//           },
//     ),
//   );

//   sl.registerFactory(
//     () => EditProfileCubit(
//       fetchMyProfile: sl(),
//       updateProfile: sl(),
//       profileRepo: sl(),
//       authLocal: sl(),
//       getCurrentUser: sl(),
//     ),
//   );

//   // --------- Initialize feature modules ---------
//   _initializeClubsModule();
//   _initializeLiveModule();
//   registerProfileView();
//   registerChat();
//   wallet();
//   setWalletPin();
//   transfercoin();
//   withdrawal();
//   registerPosts();
//   creatPost();
//   liveFeeds();
//   await _initializePusherService();

//   // --------- Register Realtime Unread Services ---------
//   _registerRealtimeUnreadServices();

//   _initializeLiveViewerServices();
//   // Like memory
//   sl.registerLazySingleton<LikeMemory>(() => LikeMemory(prefs));

//   // Feed
//   sl.registerLazySingleton(() => FeedRemoteDataSource(sl<DioClient>()));
//   sl.registerLazySingleton<FeedRepository>(() => FeedRepositoryImpl(sl()));
//   sl.registerFactory(() => FeedCubit(sl()));

//   // --------- Initialize Pusher LAST (after all dependencies are registered) ---------
//   // await _initializePusher();

//   debugPrint('✅ [INIT] Full dependency initialization complete');

//   DependencyManager.markAllDependenciesReady();
// }

// // REPLACE THE _initializePusherWithOtherServices FUNCTION WITH THIS:
// // Future<void> _initializePusher() async {
// //   debugPrint('🔧 [INIT] Initializing Pusher service...');

// //   // Register PusherService first
// //   if (!sl.isRegistered<PusherService>()) {
// //     sl.registerLazySingleton<PusherService>(() {
// //       debugPrint('🎯 Creating PusherService instance');
// //       return PusherService();
// //     });
// //   }

// //   // Now initialize Pusher
// //   try {
// //     final pusher = sl<PusherService>();
// //     if (pusher.isInitialized) {
// //       debugPrint('✅ Pusher already initialized');
// //       return;
// //     }

// //     final cfg = sl<RuntimeConfig>();
// //     if (cfg.pusherKey.isEmpty) {
// //       debugPrint(
// //         '⚠️ Pusher key empty, skipping initialization (check your environment)',
// //       );
// //       return;
// //     }

// //     debugPrint('🔧 Initializing PusherService with configuration...');

// //     // Get auth token for callback
// //     final authLocal = sl<AuthLocalDataSource>();
// //     final dio = sl<Dio>(instanceName: 'mainDio');

// //     await pusher.initialize(
// //       apiKey: cfg.pusherKey,
// //       cluster: cfg.pusherCluster,
// //       authEndpoint: '${cfg.apiBaseUrl}/broadcasting/auth',
// //       authCallback: (channelName, socketId, options) async {
// //         final token = await authLocal.readToken();
// //         if (token == null || token.isEmpty) {
// //           throw Exception('No auth token');
// //         }

// //         final response = await dio.post(
// //           '/broadcasting/auth',
// //           data: {'socket_id': socketId, 'channel_name': channelName},
// //           options: Options(
// //             headers: {
// //               'Accept': 'application/json',
// //               'Authorization': 'Bearer $token',
// //             },
// //           ),
// //         );
// //         return response.data;
// //       },
// //     );

// //     debugPrint('✅ PusherService initialized successfully');
// //   } catch (e) {
// //     debugPrint('⚠️ Pusher initialization failed (non-critical): $e');
// //     // Don't throw - Pusher is optional for ap
// //     //p startup
// //   }
// // }

// Future<void> ensurePusherInitialized() async {
//   await _initializePusherService();
// }

// Future<void> _initializePusherService() async {
//   debugPrint('🔧 [INIT] Initializing Pusher service...');

//   try {
//     // 1. Register PusherService if not already registered
//     if (!sl.isRegistered<PusherService>()) {
//       sl.registerLazySingleton<PusherService>(() {
//         debugPrint('🎯 Creating PusherService instance');
//         return PusherService();
//       });
//     }

//     final pusher = sl<PusherService>();
//     final cfg = sl<RuntimeConfig>();

//     // 2. If Pusher is already initialized in bad state, we need to fix it
//     if (pusher.isInitialized && pusher.isInBadState) {
//       debugPrint(
//         '⚠️ Pusher is in bad state (disabled key), will fix when config is ready',
//       );

//       // Don't try to initialize with bad config
//       // It will be fixed by RuntimeConfigRefreshService
//       return;
//     }

//     // 3. Skip if already initialized with proper keys
//     if (pusher.isInitialized &&
//         cfg.pusherKey.isNotEmpty &&
//         cfg.pusherKey != 'disabled') {
//       debugPrint('✅ Pusher already properly initialized');

//       // Just ensure it's connected
//       if (!pusher.isConnected) {
//         await pusher.connect();
//       }
//       return;
//     }

//     // 4. Check if we have valid Pusher configuration
//     if (cfg.pusherKey.isEmpty || cfg.pusherKey == 'disabled') {
//       debugPrint(
//         '⚠️ Pusher key empty or disabled - chat real-time features disabled',
//       );
//       debugPrint(
//         '   To enable real-time chat, add PUSHER_KEY to your .env file',
//       );

//       // Initialize with disabled state (temporary)
//       await pusher.initialize(
//         apiKey: 'disabled',
//         cluster: 'mt1',
//         authEndpoint: null,
//         authCallback: null,
//       );

//       debugPrint('✅ Pusher initialized in disabled state');
//       return;
//     }

//     // 5. Initialize with proper configuration
//     debugPrint('🔧 Initializing Pusher with proper configuration...');

//     await pusher.initialize(
//       apiKey: cfg.pusherKey,
//       cluster: cfg.pusherCluster,
//       authEndpoint: '${cfg.apiBaseUrl}/broadcasting/auth',
//       authCallback: (channelName, socketId, options) async {
//         try {
//           final token = await sl<AuthLocalDataSource>().readToken();
//           if (token == null || token.isEmpty) {
//             throw Exception('No auth token for Pusher');
//           }

//           final dio = sl<Dio>(instanceName: 'mainDio');
//           final response = await dio.post(
//             '/broadcasting/auth',
//             data: {'socket_id': socketId, 'channel_name': channelName},
//             options: Options(
//               headers: {
//                 'Accept': 'application/json',
//                 'Authorization': 'Bearer $token',
//               },
//             ),
//           );
//           return response.data;
//         } catch (e) {
//           debugPrint('❌ Pusher auth failed: $e');
//           rethrow;
//         }
//       },
//     );

//     debugPrint('✅ PusherService initialized successfully');

//     // 6. Start the refresh service
//     await RuntimeConfigRefreshService().startMonitoring();
//   } catch (e) {
//     debugPrint('⚠️ Pusher initialization failed: $e');
//     // Don't throw - allow app to continue without Pusher
//   }
// }

// void _initializeClubsModule() {
//   // Clubs data source
//   sl.registerLazySingleton<ClubsRemoteDataSource>(
//     () => ClubsRemoteDataSourceImpl(sl<Dio>(instanceName: 'mainDio')),
//   );

//   // Clubs repository
//   sl.registerLazySingleton<ClubsRepository>(
//     () => ClubsRepositoryImpl(sl<ClubsRemoteDataSource>()),
//   );

//   // Clubs cubits
//   sl.registerFactory<MyClubsCubit>(() => MyClubsCubit(sl<ClubsRepository>()));
//   sl.registerFactory<DiscoverClubsCubit>(
//     () => DiscoverClubsCubit(sl<ClubsRepository>()),
//   );
//   sl.registerFactory<ClubProfileCubit>(
//     () => ClubProfileCubit(sl<ClubsRepository>()),
//   );
//   sl.registerFactory<SuggestedClubsCubit>(
//     () => SuggestedClubsCubit(sl<ClubsRepository>()),
//   );

//   // Club income
//   sl.registerLazySingleton<ClubIncomeRemoteDataSource>(
//     () => ClubIncomeRemoteDataSource(sl<Dio>(instanceName: 'mainDio')),
//   );

//   sl.registerLazySingleton<ClubIncomeRepository>(
//     () => ClubIncomeRepositoryImpl(sl<ClubIncomeRemoteDataSource>()),
//   );

//   sl.registerFactory<ClubIncomeCubit>(
//     () => ClubIncomeCubit(sl<ClubIncomeRepository>(), ''),
//   );

//   sl.registerFactory<CreateClubCubit>(
//     () => CreateClubCubit(sl<ClubsRepository>()),
//   );

//   sl.registerFactoryParam<EditClubCubit, String, void>(
//     (clubUuid, _) =>
//         EditClubCubit(repository: sl<ClubsRepository>(), clubUuid: clubUuid),
//   );

//   sl.registerFactoryParam<ClubMembersCubit, String, void>(
//     (clubSlug, _) =>
//         ClubMembersCubit(repo: sl<ClubsRepository>(), club: clubSlug),
//   );

//   sl.registerFactoryParam<DonateClubCubit, String, void>(
//     (club, _) => DonateClubCubit(repository: sl<ClubsRepository>(), club: club),
//   );
// }

// void _initializeLiveModule() {
//   // Agora service
//   if (!sl.isRegistered<AgoraService>()) {
//     sl.registerLazySingleton<AgoraService>(() => AgoraService());
//   }

//   // Camera and audio services
//   sl.registerLazySingleton<CameraService>(() => RealCameraService());
//   sl.registerLazySingleton<AudioTestService>(() => RecordAudioTestService());

//   // Live session tracker
//   if (!sl.isRegistered<LiveSessionTracker>()) {
//     sl.registerLazySingleton<LiveSessionTracker>(() => LiveSessionTracker());
//   }

//   // Live repositories
//   sl.registerLazySingleton<GoLiveRepository>(
//     () => GoLiveRepositoryImpl(sl<DioClient>()),
//   );

//   sl.registerLazySingleton<LiveSessionRepository>(
//     () => LiveSessionRepositoryImpl(
//       sl<DioClient>(),
//       sl<PusherService>(), // Will be initialized lazily
//       sl<AgoraService>(),
//       sl<LiveSessionTracker>(),
//     ),
//   );

//   // Live cubits/blocs
//   sl.registerFactory<GoLiveCubit>(
//     () => GoLiveCubit(
//       sl<GoLiveRepository>(),
//       sl<CameraService>(),
//       sl<AudioTestService>(),
//     ),
//   );

//   sl.registerFactory<LiveHostBloc>(
//     () => LiveHostBloc(sl<LiveSessionRepository>(), sl<AgoraService>()),
//   );

//   // Participants (will be registered per session)
//   sl.registerFactory<ParticipantsBloc>(
//     () => ParticipantsBloc(sl<ParticipantsRepository>()),
//   );
// }

// // void _registerPusherLazy() {
// //   if (sl.isRegistered<PusherService>()) {
// //     debugPrint('⚠️ PusherService already registered');
// //     return;
// //   }

// //   // Register as LazySingleton
// //   sl.registerLazySingleton<PusherService>(() {
// //     debugPrint('🎯 Creating PusherService instance (lazy)...');
// //     return PusherService();
// //   });

// //   // DON'T wait 3 seconds - initialize immediately after auth
// //   // Remove the Future.delayed and initialize when Chat might be accessed
// // }

// void registerProfileView() {
//   sl.registerLazySingleton<view_ds.ProfileRemoteDataSource>(
//     () => view_ds.ProfileRemoteDataSource(sl<DioClient>()),
//   );
//   sl.registerLazySingleton<view_repo.ProfileRepository>(
//     () => view_repo_impl.ProfileRepositoryImpl(
//       sl<view_ds.ProfileRemoteDataSource>(),
//     ),
//   );
//   sl.registerFactory<ProfileCubit>(
//     () => ProfileCubit(sl<view_repo.ProfileRepository>()),
//   );
// }

// void _registerRealtimeUnreadServices() {
//   debugPrint('🔔 Registering Realtime Unread Services...');

//   // Register RealtimeUnreadService as singleton
//   if (!sl.isRegistered<RealtimeUnreadService>()) {
//     sl.registerSingleton<RealtimeUnreadService>(RealtimeUnreadService());
//     debugPrint('✅ RealtimeUnreadService registered');
//   }

//   // Register UnreadBadgeService as singleton (for easy widget access)
//   if (!sl.isRegistered<UnreadBadgeService>()) {
//     sl.registerSingleton<UnreadBadgeService>(UnreadBadgeService());
//     debugPrint('✅ UnreadBadgeService registered');
//   }
// }

// // In injection_container.dart, update the registerChat() function:

// void registerChat() {
//   sl.registerLazySingleton<ChatRepository>(() {
//     final repo = ChatRepositoryImpl(
//       sl<DioClient>(),
//       sl<PusherService>(),
//       sl<AuthLocalDataSource>(),
//     );

//     return repo;
//   });

//   sl.registerFactory<ChatCubit>(
//     () => ChatCubit(sl<ChatRepository>(), sl<CurrentUserService>()),
//   );
// }

// void wallet() {
//   sl.registerLazySingleton<RemoteWalletDataSource>(
//     () => RemoteWalletDataSource(client: sl<Dio>(instanceName: 'mainDio')),
//   );
//   sl.registerLazySingleton<WalletRepository>(
//     () => WalletRepositoryImpl(remote: sl<RemoteWalletDataSource>()),
//   );
//   sl.registerFactory<WalletCubit>(() => WalletCubit(sl<WalletRepository>()));
//   sl.registerLazySingleton<IdempotencyHelper>(
//     () => IdempotencyHelper(sl<SharedPreferences>()),
//   );
//   sl.registerLazySingleton<PlayBillingService>(
//     () => PlayBillingService(
//       repo: sl<WalletRepository>() as WalletRepositoryImpl,
//       idem: sl<IdempotencyHelper>(),
//     ),
//   );
// }

// // Update the setWalletPin() function
// void setWalletPin() {
//   sl.registerLazySingleton<PinRemoteDataSource>(
//     () => PinRemoteDataSource(sl<DioClient>()),
//   );

//   // Keep existing PinRepository registration
//   sl.registerLazySingleton<PinRepository>(
//     () => PinRepositoryImpl(sl<PinRemoteDataSource>()),
//   );

//   // sl.registerLazySingleton<SetPin>(() => SetPin(sl<PinRepository>()));

//   // // Register new PIN cubits
//   // sl.registerFactory<SetPinCubit>(
//   //   () => SetPinCubit(setPinUsecase: sl<SetPin>()),
//   // );

//   // sl.registerFactory<ResetPinCubit>(() => ResetPinCubit(sl<PinRepository>()));

//   // sl.registerFactory<SetNewPinCubit>(
//   //   () => SetNewPinCubit(pinRepository: sl<PinRepository>()),
//   // );
// }

// void transfercoin() {
//   sl.registerLazySingleton<GiftRemoteDataSource>(
//     () => GiftRemoteDataSource(sl<DioClient>()),
//   );
//   sl.registerLazySingleton<GiftRepository>(
//     () => GiftRepositoryImpl(sl<GiftRemoteDataSource>()),
//   );
//   sl.registerFactory<TransferCubit>(
//     () => TransferCubit(repository: sl<GiftRepository>()),
//   );
// }

// void withdrawal() {
//   sl.registerLazySingleton<WithdrawalRemoteDataSource>(
//     () => WithdrawalRemoteDataSource(sl<DioClient>()),
//   );
//   sl.registerLazySingleton<WithdrawalRepository>(
//     () => WithdrawalRepositoryImpl(sl<WithdrawalRemoteDataSource>()),
//   );
//   sl.registerFactory<WithdrawalCubit>(
//     () => WithdrawalCubit(repository: sl<WithdrawalRepository>()),
//   );
// }

// void liveFeeds() {
//   // Check if already registered
//   if (sl.isRegistered<LiveFeedBloc>()) {
//     debugPrint('⚠️ LiveFeedBloc already registered');
//     return;
//   }

//   // Make sure DioClient is registered first
//   if (!sl.isRegistered<DioClient>()) {
//     debugPrint('❌ DioClient not registered for LiveFeedRemoteDataSource');
//     return;
//   }

//   debugPrint('📡 Registering LiveFeed dependencies...');

//   try {
//     // ✅ FIXED: Use the factory constructor that accepts DioClient
//     sl.registerLazySingleton<LiveFeedRemoteDataSource>(() {
//       debugPrint('🔄 Creating LiveFeedRemoteDataSource');
//       final dioClient = sl<DioClient>();
//       return LiveFeedRemoteDataSourceImpl.fromDioClient(dioClient);
//     });

//     // Register repository
//     sl.registerLazySingleton<LiveFeedRepository>(() {
//       debugPrint('🔄 Creating LiveFeedRepository');
//       final dataSource = sl<LiveFeedRemoteDataSource>();
//       return LiveFeedRepositoryImpl(dataSource);
//     });

//     // Register bloc (FACTORY - creates new instance each time)
//     sl.registerFactory<LiveFeedBloc>(() {
//       debugPrint('🔄 Creating LiveFeedBloc');
//       final repository = sl<LiveFeedRepository>();
//       return LiveFeedBloc(repository);
//     });

//     debugPrint('✅ LiveFeed dependencies registered successfully');
//   } catch (e, stack) {
//     debugPrint('❌ Error registering LiveFeed dependencies: $e');
//     debugPrint('Stack: $stack');
//   }
// }

// void registerPosts() {
//   // Add cache interceptor if needed
//   // sl<Dio>(instanceName: 'mainDio').interceptors.add(EtagCacheInterceptor());

//   sl.registerLazySingleton<PostRemoteDataSource>(
//     () => PostRemoteDataSource(sl<DioClient>()),
//   );
//   sl.registerLazySingleton<PostRepository>(
//     () => PostRepositoryImpl(sl<PostRemoteDataSource>()),
//   );
//   sl.registerFactoryParam<PostCubit, String, void>((postId, _) {
//     return PostCubit(sl<PostRepository>(), postId);
//   });
// }

// void creatPost() {
//   sl.registerLazySingleton<CreatePostRemoteDataSource>(
//     () => CreatePostRemoteDataSource(sl<DioClient>()),
//   );
//   sl.registerLazySingleton<CreatePostRepository>(
//     () => CreatePostRepositoryImpl(sl<CreatePostRemoteDataSource>()),
//   );
//   sl.registerFactory<CreatePostCubit>(
//     () => CreatePostCubit(sl<CreatePostRepository>()),
//   );
// }

// // Add this to injection_container.dart, near the top
// class DependencyManager {
//   static final Completer<void> _allDependenciesReady = Completer<void>();
//   static bool _isInitialized = false;

//   static Future<void> waitForAllDependencies() async {
//     if (_isInitialized) return;
//     return _allDependenciesReady.future;
//   }

//   static void markAllDependenciesReady() {
//     if (!_allDependenciesReady.isCompleted) {
//       _isInitialized = true;
//       _allDependenciesReady.complete();
//       debugPrint('✅ All dependencies are ready');
//     }
//   }

//   static bool get isReady => _isInitialized;
// }
