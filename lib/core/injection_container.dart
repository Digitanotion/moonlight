// lib/core/injection_container.dart
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/network/interceptors/cache_interceptor.dart';
import 'package:moonlight/core/services/host_pusher_service.dart';
import 'package:moonlight/core/services/like_memory.dart';
import 'package:moonlight/features/create_post/data/datasources/create_post_remote_datasource.dart';
import 'package:moonlight/features/create_post/data/repositories/create_post_repository_impl.dart';
import 'package:moonlight/features/create_post/domain/repositories/create_post_repository.dart';
import 'package:moonlight/features/create_post/presentation/cubit/create_post_cubit.dart';
import 'package:moonlight/features/feed/data/datasources/feed_remote_datasource.dart';
import 'package:moonlight/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:moonlight/features/feed/domain/repositories/feed_repository.dart';
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/home/data/datasources/live_feed_remote_datasource.dart';
import 'package:moonlight/features/home/data/repositories/live_feed_repository_impl.dart';
import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_bloc.dart';
import 'package:moonlight/features/livestream/data/repositories/participants_repository_impl.dart';
import 'package:moonlight/features/livestream/domain/repositories/participants_repository.dart';
import 'package:moonlight/features/livestream/presentation/bloc/participants_bloc.dart';
import 'package:moonlight/features/post_view/data/datasources/post_remote_datasource.dart';
import 'package:moonlight/features/post_view/data/repositories/post_repository_impl.dart';
import 'package:moonlight/features/post_view/domain/repositories/post_repository.dart';
import 'package:moonlight/features/post_view/presentation/cubit/post_cubit.dart';
import 'package:moonlight/features/profile_view/presentation/cubit/profile_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonlight/core/config/runtime_config.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';

import 'package:moonlight/core/services/google_signin_service.dart';

// AUTH
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:moonlight/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:moonlight/features/auth/domain/repositories/auth_repository.dart';
import 'package:moonlight/features/auth/domain/usecases/get_current_user.dart';
import 'package:moonlight/features/auth/domain/usecases/check_auth_status.dart'
    hide Logout;
import 'package:moonlight/features/auth/domain/usecases/logout.dart';
import 'package:moonlight/features/auth/domain/usecases/login_with_email.dart';
import 'package:moonlight/features/auth/domain/usecases/sign_up_with_email.dart';
import 'package:moonlight/features/auth/domain/usecases/social_login.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';

// ONBOARDING
import 'package:moonlight/features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'package:moonlight/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:moonlight/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';

// SEARCH
import 'package:moonlight/features/search/data/datasources/search_remote_data_source.dart';
import 'package:moonlight/features/search/data/repositories/search_repository_impl.dart';
import 'package:moonlight/features/search/domain/repositories/search_repository.dart';
import 'package:moonlight/features/search/domain/usecases/get_popular_clubs.dart';
import 'package:moonlight/features/search/domain/usecases/get_suggested_users.dart';
import 'package:moonlight/features/search/domain/usecases/get_trending_tags.dart';
import 'package:moonlight/features/search/domain/usecases/search_content.dart';
import 'package:moonlight/features/search/presentation/bloc/search_bloc.dart';

// PROFILE/SETTINGS
import 'package:moonlight/features/profile_setup/data/datasources/country_local_data_source.dart';
import 'package:moonlight/features/profile_setup/data/datasources/profile_remote_data_source.dart';
import 'package:moonlight/features/profile_setup/data/repositories/profile_repository_impl.dart';
import 'package:moonlight/features/profile_setup/domain/repositories/profile_repository.dart';
import 'package:moonlight/features/profile_setup/domain/usecases/fetch_my_profile.dart';
import 'package:moonlight/features/profile_setup/domain/usecases/setup_profile.dart';
import 'package:moonlight/features/profile_setup/domain/usecases/update_interests.dart';
import 'package:moonlight/features/profile_setup/domain/usecases/update_profile.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_page_cubit.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_setup_cubit.dart';
import 'package:moonlight/features/edit_profile/presentation/cubit/edit_profile_cubit.dart';
import 'package:moonlight/features/settings/data/datasources/account_remote_data_source.dart';
import 'package:moonlight/features/settings/data/repositories/account_repository_impl.dart';
import 'package:moonlight/features/settings/domain/repositories/account_repository.dart';
import 'package:moonlight/features/settings/domain/usecases/deactivate_account.dart';
import 'package:moonlight/features/settings/domain/usecases/delete_account.dart';
import 'package:moonlight/features/settings/domain/usecases/reactivate_account.dart';
import 'package:moonlight/features/settings/presentation/cubit/account_settings_cubit.dart';
import 'package:moonlight/features/user_interest/presentation/cubit/user_interest_cubit.dart';

// LIVE
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_mock.dart';
import 'package:moonlight/features/live_viewer/domain/repositories/viewer_repository.dart';
import 'package:moonlight/features/livestream/data/repositories/go_live_repository_impl.dart';
import 'package:moonlight/features/livestream/domain/repositories/go_live_repository.dart';
import 'package:moonlight/features/livestream/data/repositories/live_session_repository_impl.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_session_repository.dart';
import 'package:moonlight/features/livestream/data/services/audio_test_service_impl.dart';
import 'package:moonlight/features/livestream/data/services/camera_service_impl.dart';
import 'package:moonlight/features/livestream/domain/services/audio_test_service.dart';
import 'package:moonlight/features/livestream/domain/services/camera_service.dart';
import 'package:moonlight/features/livestream/domain/session/live_session_tracker.dart';
import 'package:moonlight/features/livestream/presentation/bloc/live_host_bloc.dart';
import 'package:moonlight/features/livestream/presentation/cubits/go_live_cubit.dart';

final sl = GetIt.instance;

/// Used ONLY to bootstrap `/api/config` before we know the real base URL.
/// Must be your final host (no trailing slash).
const _fallbackHost = 'https://svc.moonlightstream.app';

Future<void> init() async {
  // --------- Core singletons ---------
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => prefs);
  sl.registerLazySingleton<DeviceInfoPlugin>(() => DeviceInfoPlugin());
  sl.registerLazySingleton<GoogleSignInService>(() => GoogleSignInService());

  // Local auth (provides token for DioClient)
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: prefs),
  );

  // --------- Bootstrap /api/config (public or Sanctum-protected) ---------
  final bootstrap = Dio(
    BaseOptions(
      baseUrl: '$_fallbackHost/api',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );
  bootstrap.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await sl<AuthLocalDataSource>().readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  // Load runtime config (with fallback if API is unreachable)
  // --------- Load RuntimeConfig FIRST ---------
  debugPrint('🔄 STEP 1: Loading RuntimeConfig...');
  RuntimeConfig cfg;
  try {
    cfg = await ConfigServiceHttp(bootstrap).load();
    debugPrint('✅ RuntimeConfig loaded successfully!');
  } catch (e) {
    debugPrint('❌ RuntimeConfig loading failed: $e');
    debugPrint('🔄 Using fallback configuration...');
    cfg = RuntimeConfig(
      agoraAppId: const String.fromEnvironment(
        'AGORA_APP_ID',
        defaultValue: '',
      ),
      apiBaseUrl: _fallbackHost,
      pusherKey: const String.fromEnvironment('PUSHER_KEY', defaultValue: ''),
      pusherCluster: const String.fromEnvironment(
        'PUSHER_CLUSTER',
        defaultValue: 'mt1',
      ),
    );
  }
  sl.registerLazySingleton<RuntimeConfig>(() => cfg);

  // --------- Real DioClient (uses base host from config) ---------
  // IMPORTANT: Repos use absolute paths like '/api/v1/...'
  // so baseUrl should be just the root domain.
  final dioClient = DioClient(cfg.apiBaseUrl, sl<AuthLocalDataSource>());
  sl.registerLazySingleton<DioClient>(() => dioClient);
  sl.registerLazySingleton<Dio>(() => dioClient.dio);

  // --------- Data sources ---------
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl<Dio>()),
  );
  sl.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<CountryLocalDataSource>(
    () => CountryLocalDataSourceImpl(),
  );
  sl.registerLazySingleton<AccountRemoteDataSource>(
    () => AccountRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<SearchRemoteDataSource>(
    () => SearchRemoteDataSourceImpl(),
  );

  // --------- Repositories ---------
  sl.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<AccountRepository>(
    () => AccountRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      remote: sl(),
      countryLocal: sl(),
      local: sl<AuthLocalDataSource>(),
    ),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      deviceInfo: sl(),
      googleSignInService: sl(),
    ),
  );

  // --------- Use cases ---------
  sl.registerLazySingleton<GetCurrentUser>(() => GetCurrentUser(sl()));
  sl.registerLazySingleton<CheckAuthStatus>(() => CheckAuthStatus(sl()));
  sl.registerLazySingleton<LoginWithEmail>(() => LoginWithEmail(sl()));
  sl.registerLazySingleton<SignUpWithEmail>(() => SignUpWithEmail(sl()));
  sl.registerLazySingleton<SocialLogin>(() => SocialLogin(sl()));
  sl.registerLazySingleton<Logout>(() => Logout(sl()));
  sl.registerLazySingleton(() => DeactivateAccount(sl()));
  sl.registerLazySingleton(() => ReactivateAccount(sl()));
  sl.registerLazySingleton(() => DeleteAccount(sl()));

  sl.registerLazySingleton<SearchContent>(() => SearchContent(sl()));
  sl.registerLazySingleton<GetTrendingTags>(() => GetTrendingTags(sl()));
  sl.registerLazySingleton<GetSuggestedUsers>(() => GetSuggestedUsers(sl()));
  sl.registerLazySingleton<GetPopularClubs>(() => GetPopularClubs(sl()));
  sl.registerLazySingleton(() => SetupProfile(sl()));
  sl.registerLazySingleton(() => UpdateInterests(sl()));
  sl.registerLazySingleton(() => UpdateProfile(sl()));
  sl.registerLazySingleton(() => FetchMyProfile(sl()));

  // --------- Blocs/Cubits ---------
  sl.registerFactory<OnboardingBloc>(() => OnboardingBloc(repository: sl()));
  sl.registerFactory<SearchBloc>(
    () => SearchBloc(
      searchContent: sl(),
      getTrendingTags: sl(),
      getSuggestedUsers: sl(),
      getPopularClubs: sl(),
    ),
  );
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      loginWithEmail: sl(),
      signUpWithEmail: sl(),
      socialLogin: sl(),
      checkAuthStatusUseCase: sl(),
      logout: sl(),
      getCurrentUser: sl(),
      authRepository: sl(),
    ),
  );

  sl.registerFactory(() => ProfileSetupCubit(sl(), sl()));
  sl.registerFactory(() => UserInterestCubit(sl()));
  sl.registerFactory(() => ProfilePageCubit(fetchMyProfile: sl()));
  sl.registerFactory(
    () => EditProfileCubit(
      fetchMyProfile: sl(),
      updateProfile: sl(),
      profileRepo: sl(),
      authLocal: sl(),
      getCurrentUser: sl(),
    ),
  );
  sl.registerFactory<AccountSettingsCubit>(
    () => AccountSettingsCubit(
      deactivateAccount: sl(),
      reactivateAccount: sl(),
      deleteAccount: sl(),
      prefs: sl(),
    ),
  );
  //Live Feeds for Homepage
  liveFeeds();
  // ======= Live stack (order matters) =======
  _registerPusher(); // needs RuntimeConfig
  _registerAgora(); // agora engine
  _registerGoLive(); // camera/mic + go live repo
  _registerLiveHost(); // session repo (agora + pusher)
  _registerLiveViewer(); // viewer mock (until implemented)
  registerPosts();
  creatPost();
  sl.registerLazySingleton<LikeMemory>(
    () => LikeMemory(sl<SharedPreferences>()),
  );
  // ---- FEED ----
  sl.registerLazySingleton(() => FeedRemoteDataSource(sl<DioClient>()));
  sl.registerLazySingleton<FeedRepository>(() => FeedRepositoryImpl(sl()));
  sl.registerFactory(() => FeedCubit(sl()));

  // ---- PROFILE VIEW ----

  sl.registerFactory(() => ProfileCubit(sl()));
}

/// Call this right before opening the Viewers List, when you *know* the ids.
/// It will (re)register the repository with the current livestream identifiers.
///
/// `livestreamIdNumeric` -> for Pusher channels: `live.{id}`
/// `livestreamParam`     -> REST segment (numeric id **or** UUID) for /api paths
void registerParticipantsScope({
  required int livestreamIdNumeric,
  required String livestreamParam,
}) {
  // Repo is session-scoped: drop the old one if any (e.g., previous live)
  if (sl.isRegistered<ParticipantsRepository>()) {
    try {
      sl<ParticipantsRepository>().dispose();
    } catch (_) {}
    sl.unregister<ParticipantsRepository>();
  }

  sl.registerLazySingleton<ParticipantsRepository>(
    () => ParticipantsRepositoryImpl(
      sl<DioClient>(),
      sl<PusherService>(),
      livestreamIdNumeric: livestreamIdNumeric,
      livestreamParam: livestreamParam,
    ),
  );

  // Optional: factory for the BLoC (useful if you prefer sl<ParticipantsBloc>())
  if (sl.isRegistered<ParticipantsBloc>()) {
    sl.unregister<ParticipantsBloc>();
  }
  sl.registerFactory<ParticipantsBloc>(
    () => ParticipantsBloc(sl<ParticipantsRepository>()),
  );
}

/// Call this when the viewers list is no longer needed (optional but tidy).
Future<void> unregisterParticipantsScope() async {
  if (sl.isRegistered<ParticipantsRepository>()) {
    try {
      await sl<ParticipantsRepository>().dispose();
    } catch (_) {}
    sl.unregister<ParticipantsRepository>();
  }
  if (sl.isRegistered<ParticipantsBloc>()) {
    sl.unregister<ParticipantsBloc>();
  }
}

void _registerAgora() {
  if (!sl.isRegistered<AgoraService>()) {
    sl.registerLazySingleton<AgoraService>(() => AgoraService());
  }
}

void _registerGoLive() {
  // Services for device preflight
  sl.registerLazySingleton<CameraService>(() => RealCameraService());
  sl.registerLazySingleton<AudioTestService>(() => RecordAudioTestService());

  // Repos
  sl.registerLazySingleton<GoLiveRepository>(
    () => GoLiveRepositoryImpl(sl<DioClient>()),
  );

  // Cubit
  sl.registerFactory<GoLiveCubit>(
    () => GoLiveCubit(
      sl<GoLiveRepository>(),
      sl<CameraService>(),
      sl<AudioTestService>(),
    ),
  );
}

void _registerLiveViewer() {
  // sl.registerLazySingleton<ViewerRepository>(() => ViewerRepositoryMock());
}

// In your injection_container.dart - remove HostPusherService registration
void _registerPusher() {
  if (sl.isRegistered<PusherService>()) {
    debugPrint('⚠️ PusherService already registered');
    return;
  }

  final cfg = sl<RuntimeConfig>();

  debugPrint('🔧 Registering PusherService with:');
  debugPrint('   - pusherKey: "${cfg.pusherKey}"');
  debugPrint('   - pusherCluster: "${cfg.pusherCluster}"');
  debugPrint('   - keyIsEmpty: ${cfg.pusherKey.isEmpty}');

  if (cfg.pusherKey.isEmpty) {
    debugPrint('❌ ERROR: Pusher key is empty in RuntimeConfig!');
    debugPrint('   This means the config loading failed or returned empty key');
    throw Exception('Pusher API key is empty - check config loading');
  }

  sl.registerLazySingleton<PusherService>(() {
    debugPrint('🎯 Creating PusherService instance...');
    return PusherService(apiKey: cfg.pusherKey, cluster: cfg.pusherCluster);
  });

  debugPrint('✅ PusherService registered successfully');
}

void _registerLiveHost() {
  if (!sl.isRegistered<LiveSessionTracker>()) {
    sl.registerLazySingleton<LiveSessionTracker>(() => LiveSessionTracker());
  }

  sl.registerLazySingleton<LiveSessionRepository>(
    () => LiveSessionRepositoryImpl(
      sl<DioClient>(),
      sl<PusherService>(), // Use the same PusherService
      sl<AgoraService>(),
      sl<LiveSessionTracker>(),
    ),
  );

  sl.registerFactory<LiveHostBloc>(
    () =>
        LiveHostBloc(GetIt.I<LiveSessionRepository>(), GetIt.I<AgoraService>()),
  );
}

liveFeeds() {
  // Data sources
  sl.registerLazySingleton<LiveFeedRemoteDataSource>(
    () => LiveFeedRemoteDataSourceImpl(sl()),
  );

  // Repositories
  sl.registerLazySingleton<LiveFeedRepository>(
    () => LiveFeedRepositoryImpl(sl()),
  );

  // Blocs
  sl.registerFactory<LiveFeedBloc>(() => LiveFeedBloc(sl()));
}

registerPosts() {
  sl<Dio>().interceptors.add(EtagCacheInterceptor());

  // register post remote datasource + repository
  sl.registerLazySingleton<PostRemoteDataSource>(
    () => PostRemoteDataSource(sl<DioClient>()),
  );
  sl.registerLazySingleton<PostRepository>(
    () => PostRepositoryImpl(sl<PostRemoteDataSource>()),
  );

  // // small factory for PostCubit (so you can get it with a postUuid at runtime)
  // PostCubit makePostCubit(String postUuid) =>
  //     PostCubit(sl<PostRepository>(), postUuid);
}

creatPost() {
  // ---- CREATE POST ----
  sl.registerLazySingleton<CreatePostRemoteDataSource>(
    () => CreatePostRemoteDataSource(sl<DioClient>()),
  );
  sl.registerLazySingleton<CreatePostRepository>(
    () => CreatePostRepositoryImpl(sl<CreatePostRemoteDataSource>()),
  );
  sl.registerFactory<CreatePostCubit>(
    () => CreatePostCubit(sl<CreatePostRepository>()),
  );
}

// Optional helper if some legacy code still uses it.
Dio buildDio({required String baseUrl, required SharedPreferences prefs}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
      contentType: 'application/json',
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token =
            prefs.getString('access_token') ?? prefs.getString('token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) => handler.next(e),
    ),
  );
  return dio;
}
