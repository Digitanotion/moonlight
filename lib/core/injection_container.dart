// lib/core/injection_container.dart
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/network/interceptors/auth_interceptor.dart';
import 'package:moonlight/core/network/interceptors/cache_interceptor.dart';
import 'package:moonlight/core/network/interceptors/dio_extra_hook.dart';
import 'package:moonlight/core/network/interceptors/error_normalizer_interceptor.dart';
import 'package:moonlight/core/network/interceptors/idempotency_interceptor.dart';
import 'package:moonlight/core/network/interceptors/request_id_interceptor.dart';
import 'package:moonlight/core/network/interceptors/retry_interceptor.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/host_pusher_service.dart';
import 'package:moonlight/core/services/like_memory.dart';
import 'package:moonlight/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:moonlight/features/chat/data/services/chat_api_service.dart';
import 'package:moonlight/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonlight/features/chat/presentation/pages/cubit/chat_cubit.dart';
import 'package:moonlight/features/clubs/data/datasources/clubs_remote_data_source.dart';
import 'package:moonlight/features/clubs/data/repositories/clubs_repository_impl.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/presentation/cubit/discover_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart'
    show MyClubsCubit;
import 'package:moonlight/features/create_post/data/datasources/create_post_remote_datasource.dart';
import 'package:moonlight/features/create_post/data/repositories/create_post_repository_impl.dart';
import 'package:moonlight/features/create_post/domain/repositories/create_post_repository.dart';
import 'package:moonlight/features/create_post/presentation/cubit/create_post_cubit.dart';
import 'package:moonlight/features/feed/data/datasources/feed_remote_datasource.dart';
import 'package:moonlight/features/feed/data/repositories/feed_repository_impl.dart';
import 'package:moonlight/features/feed/domain/repositories/feed_repository.dart';
import 'package:moonlight/features/feed/presentation/cubit/feed_cubit.dart';
import 'package:moonlight/features/gift_coins/data/datasources/gift_local_datasource.dart';
import 'package:moonlight/features/gift_coins/data/datasources/gift_remote_datasource.dart';
import 'package:moonlight/features/gift_coins/data/repositories/gift_repository_impl.dart';
import 'package:moonlight/features/gift_coins/domain/repositories/gift_repository.dart';
import 'package:moonlight/features/gift_coins/presentation/cubit/transfer_cubit.dart';
import 'package:moonlight/features/home/data/datasources/live_feed_remote_datasource.dart';
import 'package:moonlight/features/home/data/repositories/live_feed_repository_impl.dart';
import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_bloc.dart';
import 'package:moonlight/features/livestream/data/repositories/participants_repository_impl.dart';
import 'package:moonlight/features/livestream/domain/repositories/participants_repository.dart';
import 'package:moonlight/features/livestream/presentation/bloc/participants_bloc.dart';
import 'package:moonlight/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:moonlight/features/notifications/data/repositories/notifications_repository.dart';
import 'package:moonlight/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:moonlight/features/post_view/data/datasources/post_remote_datasource.dart';
import 'package:moonlight/features/post_view/data/repositories/post_repository_impl.dart';
import 'package:moonlight/features/post_view/domain/repositories/post_repository.dart';
import 'package:moonlight/features/post_view/presentation/cubit/post_cubit.dart';
import 'package:moonlight/features/profile_view/presentation/cubit/profile_cubit.dart';
import 'package:moonlight/features/wallet/data/datasources/local_wallet_datasource.dart';
import 'package:moonlight/features/wallet/data/datasources/pin_remote_datasource.dart';
import 'package:moonlight/features/wallet/data/datasources/remote_wallet_datasource.dart';
import 'package:moonlight/features/wallet/data/repositories/pin_repository_impl.dart';
import 'package:moonlight/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:moonlight/features/wallet/domain/repositories/pin_repository.dart';
import 'package:moonlight/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:moonlight/features/wallet/domain/usecases/set_pin.dart';
import 'package:moonlight/features/wallet/presentation/cubit/set_pin_cubit.dart';
import 'package:moonlight/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:moonlight/features/wallet/services/idempotency_helper.dart';
import 'package:moonlight/features/wallet/services/play_billing_service.dart';
import 'package:moonlight/features/withdrawal/data/datasources/withdrawal_remote_datasource.dart';
import 'package:moonlight/features/withdrawal/data/repositories/withdrawal_repository_impl.dart';
import 'package:moonlight/features/withdrawal/domain/repositories/withdrawal_repository.dart';
import 'package:moonlight/features/withdrawal/presentation/cubit/withdrawal_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonlight/core/config/runtime_config.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';

import 'package:moonlight/core/services/google_signin_service.dart';
// ✅ Profile View
import 'package:moonlight/features/profile_view/data/datasources/profile_remote_datasource.dart'
    as view_ds;
import 'package:moonlight/features/profile_view/data/repositories/profile_repository_impl.dart'
    as view_repo_impl;
import 'package:moonlight/features/profile_view/domain/repositories/profile_repository.dart'
    as view_repo;
import 'package:moonlight/features/profile_view/presentation/cubit/profile_cubit.dart';

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
    () => AuthRemoteDataSourceImpl(
      client: sl<Dio>(),
      prefs: sl<SharedPreferences>(),
    ),
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
    () => SearchRemoteDataSourceImpl(sl<DioClient>()),
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

  _registerPusher(); // needs RuntimeConfig
  //NOTIFICATION
  // ---- NOTIFICATIONS ----
  sl.registerLazySingleton<NotificationsRemoteDataSource>(
    () => NotificationsRemoteDataSource(sl<DioClient>()),
  );

  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(sl<NotificationsRemoteDataSource>()),
  );

  sl.registerFactory<NotificationsBloc>(
    () => NotificationsBloc(sl<NotificationsRepository>()),
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
      currentUserService: sl(), // Add this
    ),
  );

  sl.registerFactory(() => ProfileSetupCubit(sl(), sl()));
  sl.registerFactory(() => UserInterestCubit(sl()));
  // Provide ProfilePageCubit with an inline fetchMyPosts adapter that uses the profile_view repo.
  // The adapter resolves the repo only when invoked (lazy), so registration order is not an issue.
  sl.registerFactory(
    () => ProfilePageCubit(
      fetchMyProfile: sl(),
      fetchMyPosts:
          ({required String userUuid, int page = 1, int perPage = 50}) async {
            // Use the profile_view repository implementation to get Paginated<Post>
            final paginated = await sl<view_repo.ProfileRepository>()
                .getUserPosts(userUuid, page: page, perPage: perPage);
            return paginated.data; // List<Post>
          },
    ),
  );

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
  // Clubs data source
  sl.registerLazySingleton<ClubsRemoteDataSource>(
    () => ClubsRemoteDataSourceImpl(sl<Dio>()),
  );

  // Clubs repository
  sl.registerLazySingleton<ClubsRepository>(
    () => ClubsRepositoryImpl(sl<ClubsRemoteDataSource>()),
  );

  // Clubs cubits
  sl.registerFactory<MyClubsCubit>(() => MyClubsCubit(sl<ClubsRepository>()));

  sl.registerFactory<DiscoverClubsCubit>(
    () => DiscoverClubsCubit(sl<ClubsRepository>()),
  );

  sl.registerFactory<RequestIdInterceptor>(() => RequestIdInterceptor());
  sl.registerFactory<IdempotencyInterceptor>(
    () => IdempotencyInterceptor(sl<SharedPreferences>()),
  );
  sl.registerFactory<ErrorNormalizerInterceptor>(
    () => ErrorNormalizerInterceptor(),
  );
  sl.registerFactory<RetryInterceptor>(() => RetryInterceptor(maxRetries: 3));
  sl.registerFactory<AuthInterceptor>(
    () =>
        AuthInterceptor(sl<AuthLocalDataSource>(), sl<AuthRemoteDataSource>()),
  );
  sl.registerFactory<DioExtraHook>(() => DioExtraHook(sl<Dio>()));

  // attach interceptors
  final dioInstance = sl<Dio>();
  dioInstance.interceptors.add(sl<DioExtraHook>());
  dioInstance.interceptors.add(sl<RequestIdInterceptor>());
  dioInstance.interceptors.add(sl<AuthInterceptor>());
  dioInstance.interceptors.add(sl<IdempotencyInterceptor>());
  dioInstance.interceptors.add(sl<ErrorNormalizerInterceptor>());
  dioInstance.interceptors.add(sl<RetryInterceptor>());

  // If WalletRepositoryImpl currently expects only Local, update constructor to accept remote as well or create a new impl.
  // Example: register a small factory that picks remote by default
  // sl.registerLazySingleton<WalletRepository>(
  //   () => WalletRepositoryImpl(
  //     local: sl<LocalWalletDataSource>(),
  //     remote: sl<RemoteWalletDataSource>(),
  //   ),
  // );
  // Current User Service
  sl.registerLazySingleton(() => CurrentUserService());
  //Live Feeds for Homepage
  liveFeeds();
  // ======= Live stack (order matters) =======
  _registerAgora(); // agora engine
  _registerGoLive(); // camera/mic + go live repo
  _registerLiveHost(); // session repo (agora + pusher)
  _registerLiveViewer(); // viewer mock (until implemented)
  registerProfileView();
  registerChat();
  wallet();
  setWalletPin();
  transfercoin();
  withdrawal();
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

  // sl.registerFactory(() => ProfileCubit(sl()));
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

void registerProfileView() {
  // ===== PROFILE VIEW
  sl.registerLazySingleton<view_ds.ProfileRemoteDataSource>(
    () => view_ds.ProfileRemoteDataSource(sl<DioClient>()),
  );
  sl.registerLazySingleton<view_repo.ProfileRepository>(
    () => view_repo_impl.ProfileRepositoryImpl(
      sl<view_ds.ProfileRemoteDataSource>(),
    ),
  );
  sl.registerFactory<ProfileCubit>(
    () => ProfileCubit(sl<view_repo.ProfileRepository>()),
  );
}

void wallet() {
  // Data source
  // DATA SOURCE - remote only
  sl.registerLazySingleton<RemoteWalletDataSource>(
    () => RemoteWalletDataSource(client: sl<Dio>()),
  );

  // REPOSITORY - remote-only impl
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(remote: sl<RemoteWalletDataSource>()),
  );
  // CUBIT/PROVIDER
  sl.registerFactory<WalletCubit>(() => WalletCubit(sl<WalletRepository>()));

  // ID EMP helper + Play Billing service
  sl.registerLazySingleton<IdempotencyHelper>(
    () => IdempotencyHelper(sl<SharedPreferences>()),
  );
  // Play Billing service (optional - only register on Android)
  sl.registerLazySingleton<PlayBillingService>(
    () => PlayBillingService(
      repo: sl<WalletRepository>() as WalletRepositoryImpl,
      idem: sl<IdempotencyHelper>(),
    ),
  );

  // Cubit (presentation)
  // sl.registerFactory<WalletCubit>(() => WalletCubit(sl<WalletRepository>()));
  // -------------------------------------------------
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

// In registerChat() function:
void registerChat() {
  // Repository
  sl.registerLazySingleton<ChatApiService>(
    () => ChatApiService(sl<DioClient>()),
  );

  // Cubits
  sl.registerFactory<ChatCubit>(() => ChatCubit(sl<ChatRepository>()));

  // Repository - Add AuthLocalDataSource as parameter
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      sl<DioClient>(),
      sl<PusherService>(),
      sl<AuthLocalDataSource>(), // Add this
    ),
  );
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

void registerPosts() {
  sl<Dio>().interceptors.add(EtagCacheInterceptor());

  // register post remote datasource + repository
  sl.registerLazySingleton<PostRemoteDataSource>(
    () => PostRemoteDataSource(sl<DioClient>()),
  );
  sl.registerLazySingleton<PostRepository>(
    () => PostRepositoryImpl(sl<PostRemoteDataSource>()),
  );

  // ✅ FIXED: Register as factory that takes postId parameter
  sl.registerFactoryParam<PostCubit, String, void>((postId, _) {
    debugPrint('🎯 GetIt: Creating PostCubit with postId: $postId');
    final cubit = PostCubit(sl<PostRepository>(), postId);
    debugPrint('🎯 GetIt: PostCubit created successfully');
    return cubit;
  });

  // Test the registration immediately
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      debugPrint('🧪 Testing PostCubit GetIt registration...');
      final testCubit = sl<PostCubit>(param1: 'test-post-id');
      debugPrint('✅ PostCubit GetIt registration SUCCESSFUL');
    } catch (e) {
      debugPrint('❌ PostCubit GetIt registration FAILED: $e');
      debugPrint('🔄 Attempting alternative registration...');
      _registerPostCubitAlternative();
    }
  });
}

// Alternative registration method
void _registerPostCubitAlternative() {
  // Unregister if already registered
  if (sl.isRegistered<PostCubit>()) {
    sl.unregister<PostCubit>();
  }

  // Register as a factory that returns a function
  sl.registerFactory<PostCubit Function(String)>(() {
    return (postId) => PostCubit(sl<PostRepository>(), postId);
  });

  debugPrint('✅ PostCubit alternative registration complete');
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

void transfercoin() {
  // ✅ Use DioClient explicitly
  sl.registerLazySingleton<GiftRemoteDataSource>(
    () => GiftRemoteDataSource(sl<DioClient>()),
  );

  // ✅ Repository now explicitly depends on GiftRemoteDataSource
  sl.registerLazySingleton<GiftRepository>(
    () => GiftRepositoryImpl(sl<GiftRemoteDataSource>()),
  );

  // ✅ Cubit depends on strongly typed repository
  sl.registerFactory<TransferCubit>(
    () => TransferCubit(repository: sl<GiftRepository>()),
  );
}

void withdrawal() {
  // Data source
  sl.registerLazySingleton<WithdrawalRemoteDataSource>(
    () => WithdrawalRemoteDataSource(sl<DioClient>()),
  );

  // Repository
  sl.registerLazySingleton<WithdrawalRepository>(
    () => WithdrawalRepositoryImpl(sl<WithdrawalRemoteDataSource>()),
  );

  // Cubit
  sl.registerFactory<WithdrawalCubit>(
    () => WithdrawalCubit(repository: sl<WithdrawalRepository>()),
  );
}

void setWalletPin() {
  // Data source
  sl.registerLazySingleton<PinRemoteDataSource>(
    () => PinRemoteDataSourceImpl(client: sl<Dio>()),
  );

  // Repository
  sl.registerLazySingleton<PinRepository>(
    () => PinRepositoryImpl(remote: sl<PinRemoteDataSource>()),
  );

  // Usecase
  sl.registerLazySingleton<SetPin>(() => SetPin(sl<PinRepository>()));

  // Cubit (presentation)
  sl.registerFactory<SetPinCubit>(
    () => SetPinCubit(setPinUsecase: sl<SetPin>()),
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
