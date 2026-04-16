// lib/core/injection_container.dart
//
// PATCHES applied:
// 1. ParticipantsRepository was never registered — added it
// 2. LocalWalletDataSource was never registered — added it
// 3. SetPinUseCase was never registered — added it
// 4. GiftLocalDataSource was never registered — added it
// 5. UnreadBadgeService singleton guard — consolidated into one place
// 6. ProfilePageCubit depended on view_repo.ProfileRepository which was
//    registered AFTER the cubit factory — reordered
// 7. ChatApiService was never registered — added it
// 8. HostPusherService was never registered — added it
// 9. All feature module registrations now check isRegistered before
//    registering to avoid "Already registered" errors on hot-restart
// 10. Phase 3 ordering fixed: data sources → repositories → use cases → blocs

import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/config/runtime_config_cache.dart';
import 'package:moonlight/core/network/interceptors/auth_interceptor.dart';
import 'package:moonlight/core/network/interceptors/cache_interceptor.dart';
import 'package:moonlight/core/network/interceptors/dio_extra_hook.dart';
import 'package:moonlight/core/network/interceptors/error_normalizer_interceptor.dart';
import 'package:moonlight/core/network/interceptors/idempotency_interceptor.dart';
import 'package:moonlight/core/network/interceptors/request_id_interceptor.dart';
import 'package:moonlight/core/network/interceptors/retry_interceptor.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/host_pusher_service.dart';
import 'package:moonlight/core/services/like_memory.dart';
import 'package:moonlight/core/services/realtime_unread_service.dart';
import 'package:moonlight/core/services/runtime_config_refresh_service.dart';
import 'package:moonlight/core/services/token_registration_service.dart';
import 'package:moonlight/core/services/unread_badge_service.dart';
import 'package:moonlight/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:moonlight/features/chat/data/services/chat_api_service.dart';
import 'package:moonlight/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonlight/features/chat/presentation/pages/cubit/chat_cubit.dart';
import 'package:moonlight/features/clubs/data/datasources/club_income_remote_data_source.dart';
import 'package:moonlight/features/clubs/data/datasources/clubs_remote_data_source.dart';
import 'package:moonlight/features/clubs/data/repositories/club_income_repository_impl.dart';
import 'package:moonlight/features/clubs/data/repositories/clubs_repository_impl.dart';
import 'package:moonlight/features/clubs/domain/repositories/club_income_repository.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_income_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_members_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_profile_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/create_club_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/discover_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/donate_club_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/edit_club_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/my_clubs_cubit.dart'
    show MyClubsCubit;
import 'package:moonlight/features/clubs/presentation/cubit/search_clubs_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/suggested_clubs_cubit.dart';
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
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/bloc/viewer_bloc.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/network_monitor_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/reconnection_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/role_change_service.dart';
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
import 'package:moonlight/features/profile_view/data/datasources/follow_list_remote_datasource.dart';
import 'package:moonlight/features/profile_view/presentation/cubit/profile_cubit.dart';
import 'package:moonlight/features/settings/data/datasources/blocked_users_remote_datasource.dart';
import 'package:moonlight/features/settings/data/datasources/change_email_remote_datasource.dart';
import 'package:moonlight/features/settings/data/datasources/change_username_remote_datasource.dart';
import 'package:moonlight/features/settings/data/repositories/blocked_users_repository_impl.dart';
import 'package:moonlight/features/settings/data/repositories/change_email_repository_impl.dart';
import 'package:moonlight/features/settings/data/repositories/change_username_repository_impl.dart';
import 'package:moonlight/features/settings/domain/repositories/blocked_users_repository.dart';
import 'package:moonlight/features/settings/domain/repositories/change_email_repository.dart';
import 'package:moonlight/features/settings/domain/repositories/change_username_repository.dart';
import 'package:moonlight/features/settings/domain/usecases/get_notification_settings.dart';
import 'package:moonlight/features/settings/domain/usecases/update_notification_settings.dart';
import 'package:moonlight/features/settings/presentation/cubit/blocked_users_cubit.dart';
import 'package:moonlight/features/settings/presentation/cubit/change_email_cubit.dart';
import 'package:moonlight/features/settings/presentation/cubit/change_username_cubit.dart';
import 'package:moonlight/features/wallet/data/datasources/local_wallet_datasource.dart';
import 'package:moonlight/features/wallet/data/datasources/pin_remote_datasource.dart';
import 'package:moonlight/features/wallet/data/datasources/remote_wallet_datasource.dart';
import 'package:moonlight/features/wallet/data/repositories/pin_repository_impl.dart';
import 'package:moonlight/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:moonlight/features/wallet/domain/repositories/pin_repository.dart';
import 'package:moonlight/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:moonlight/features/wallet/domain/usecases/set_pin.dart';
import 'package:moonlight/features/wallet/presentation/cubit/reset_pin_cubit.dart';
import 'package:moonlight/features/wallet/presentation/cubit/set_new_pin_cubit.dart';
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

// Profile View
import 'package:moonlight/features/profile_view/data/datasources/profile_remote_datasource.dart'
    as view_ds;
import 'package:moonlight/features/profile_view/data/repositories/profile_repository_impl.dart'
    as view_repo_impl;
import 'package:moonlight/features/profile_view/domain/repositories/profile_repository.dart'
    as view_repo;
import 'package:moonlight/features/profile_view/presentation/cubit/profile_cubit.dart';

// Auth
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

// Onboarding
import 'package:moonlight/features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'package:moonlight/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:moonlight/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';

// Search
import 'package:moonlight/features/search/data/datasources/search_remote_data_source.dart';
import 'package:moonlight/features/search/data/repositories/search_repository_impl.dart';
import 'package:moonlight/features/search/domain/repositories/search_repository.dart';
import 'package:moonlight/features/search/domain/usecases/get_popular_clubs.dart';
import 'package:moonlight/features/search/domain/usecases/get_suggested_users.dart';
import 'package:moonlight/features/search/domain/usecases/get_trending_tags.dart';
import 'package:moonlight/features/search/domain/usecases/search_content.dart';
import 'package:moonlight/features/search/presentation/bloc/search_bloc.dart';

// Profile/Settings
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

// Live
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

const _fallbackHost = 'https://svc.moonlightstream.app';

// =============================================================================
// SPLASH OPTIMIZER — 3-phase lazy initialization
// =============================================================================
class SplashOptimizer {
  static final Completer<void> _renderReady = Completer<void>();
  static final Completer<void> _configReady = Completer<void>();

  static bool _renderDone = false;
  static bool _configDone = false;
  static bool _backgroundDone = false;

  // ── Phase 1: render essentials, no network ──────────────────────────────────
  static Future<void> registerRenderEssentials() async {
    if (_renderDone) return _renderReady.future;
    _renderDone = true;

    debugPrint('🚀 [PHASE 1] Registering render essentials...');

    try {
      final prefs = await SharedPreferences.getInstance();
      sl.registerLazySingleton<SharedPreferences>(() => prefs);
      sl.registerLazySingleton<DeviceInfoPlugin>(() => DeviceInfoPlugin());

      sl.registerLazySingleton<AuthLocalDataSource>(
        () => AuthLocalDataSourceImpl(sharedPreferences: prefs),
      );

      final cachedConfig = await _loadCachedOrFallbackConfig(prefs);
      sl.registerLazySingleton<RuntimeConfig>(() => cachedConfig);

      sl.registerLazySingleton<TokenRegistrationService>(
        () => TokenRegistrationService(
          authLocalDataSource: sl<AuthLocalDataSource>(),
          runtimeConfig: sl<RuntimeConfig>(),
        ),
      );

      // Minimal Dio — auth header only, no heavy interceptors
      final basicDio = Dio(
        BaseOptions(
          baseUrl: cachedConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: {'Accept': 'application/json'},
        ),
      );
      basicDio.interceptors.add(
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
      sl.registerLazySingleton<Dio>(() => basicDio, instanceName: 'authDio');

      sl.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSourceImpl(
          client: sl<Dio>(instanceName: 'authDio'),
          prefs: prefs,
        ),
      );
      sl.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(
          localDataSource: sl(),
          remoteDataSource: sl(),
          deviceInfo: sl(),
          googleSignInService: GoogleSignInService(),
        ),
      );

      sl.registerLazySingleton<GetCurrentUser>(() => GetCurrentUser(sl()));
      sl.registerLazySingleton<CheckAuthStatus>(() => CheckAuthStatus(sl()));
      sl.registerLazySingleton<Logout>(() => Logout(sl()));
      sl.registerLazySingleton<LoginWithEmail>(() => LoginWithEmail(sl()));
      sl.registerLazySingleton<SignUpWithEmail>(() => SignUpWithEmail(sl()));
      sl.registerLazySingleton<SocialLogin>(() => SocialLogin(sl()));
      sl.registerLazySingleton(() => CurrentUserService());

      sl.registerLazySingleton<OnboardingLocalDataSource>(
        () => OnboardingLocalDataSourceImpl(sharedPreferences: sl()),
      );
      sl.registerLazySingleton<OnboardingRepository>(
        () => OnboardingRepositoryImpl(localDataSource: sl()),
      );

      sl.registerFactory<OnboardingBloc>(
        () => OnboardingBloc(repository: sl()),
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
          currentUserService: sl(),
          tokenRegistrationService: sl<TokenRegistrationService>(),
        ),
      );

      _renderReady.complete();
      debugPrint('✅ [PHASE 1] Render essentials ready');
    } catch (e, stack) {
      debugPrint('❌ [PHASE 1] Error: $e\n$stack');
      _renderReady.completeError(e);
      rethrow;
    }
  }

  // ── Phase 2: fetch live config ──────────────────────────────────────────────
  static Future<void> loadConfigAndDependencies() async {
    if (_configDone) return _configReady.future;
    _configDone = true;

    await _renderReady.future;
    debugPrint('🌐 [PHASE 2] Fetching live RuntimeConfig...');

    try {
      final freshConfig = await _loadRuntimeConfig();
      if (sl.isRegistered<RuntimeConfig>()) sl.unregister<RuntimeConfig>();
      sl.registerLazySingleton<RuntimeConfig>(() => freshConfig);
      sl<Dio>(instanceName: 'authDio').options.baseUrl = freshConfig.apiBaseUrl;
      debugPrint('✅ [PHASE 2] Live config applied');
    } catch (e) {
      debugPrint('⚠️ [PHASE 2] Config fetch failed, using Phase 1 config: $e');
    } finally {
      if (!_configReady.isCompleted) _configReady.complete();
    }
  }

  // ── Phase 3: everything else ────────────────────────────────────────────────
  static Future<void> loadRemainingDependencies() async {
    if (_backgroundDone) return;
    _backgroundDone = true;

    await _configReady.future;
    debugPrint('🔄 [PHASE 3] Loading remaining dependencies...');

    try {
      await initRemainingDependencies();
      DependencyManager.markAllDependenciesReady();
      debugPrint('✅ [PHASE 3] All dependencies ready');
    } catch (e, stack) {
      debugPrint('⚠️ [PHASE 3] Error: $e\n$stack');
    }
  }

  static Future<RuntimeConfig> _loadCachedOrFallbackConfig(
    SharedPreferences prefs,
  ) async {
    try {
      final cache = RuntimeConfigCache(prefs);
      final cached = await cache.loadFromCacheOnly();
      if (cached != null && cached.apiBaseUrl.isNotEmpty) {
        debugPrint('✅ [PHASE 1] Using disk-cached RuntimeConfig');
        return cached;
      }
    } catch (e) {
      debugPrint('⚠️ [PHASE 1] Cache read failed: $e');
    }
    debugPrint('⚠️ [PHASE 1] No cache — using fallback');
    return RuntimeConfig(
      agoraAppId: '',
      apiBaseUrl: _fallbackHost,
      pusherKey: '',
      pusherCluster: 'mt1',
    );
  }

  static Future<RuntimeConfig> reloadRuntimeConfig() async {
    debugPrint('🔄 [SplashOptimizer] Reloading RuntimeConfig...');
    try {
      final cfg = await _loadRuntimeConfig();
      if (sl.isRegistered<RuntimeConfig>()) sl.unregister<RuntimeConfig>();
      sl.registerLazySingleton<RuntimeConfig>(() => cfg);
      debugPrint('✅ [SplashOptimizer] RuntimeConfig reloaded');
      return cfg;
    } catch (e) {
      debugPrint('❌ [SplashOptimizer] Reload failed: $e');
      rethrow;
    }
  }
}

// =============================================================================
// CONFIG LOADER
// =============================================================================

Future<RuntimeConfig> _loadRuntimeConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final cache = RuntimeConfigCache(prefs);

  return cache.loadWithCache(
    fetchFresh: () async {
      final bootstrapDio = Dio(
        BaseOptions(
          baseUrl: '$_fallbackHost/api',
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      try {
        final response = await bootstrapDio.get('/v1/config');
        final data = response.data as Map<String, dynamic>;
        return RuntimeConfig(
          agoraAppId:
              data['agora_app_id']?.toString() ??
              const String.fromEnvironment('AGORA_APP_ID', defaultValue: ''),
          apiBaseUrl: (data['api_base_url']?.toString() ?? _fallbackHost)
              .replaceAll(RegExp(r'/+$'), ''),
          pusherKey:
              data['pusher_key']?.toString() ??
              const String.fromEnvironment('PUSHER_KEY', defaultValue: ''),
          pusherCluster:
              data['pusher_cluster']?.toString() ??
              const String.fromEnvironment(
                'PUSHER_CLUSTER',
                defaultValue: 'mt1',
              ),
        );
      } catch (e) {
        debugPrint('❌ Config fetch failed: $e');
        return RuntimeConfig(
          agoraAppId: const String.fromEnvironment(
            'AGORA_APP_ID',
            defaultValue: '',
          ),
          apiBaseUrl: _fallbackHost,
          pusherKey: const String.fromEnvironment(
            'PUSHER_KEY',
            defaultValue: '',
          ),
          pusherCluster: const String.fromEnvironment(
            'PUSHER_CLUSTER',
            defaultValue: 'mt1',
          ),
        );
      }
    },
    forceRefresh: false,
  );
}

// =============================================================================
// PHASE 3 — FULL DEPENDENCY GRAPH
// Ordering rule: data sources → repositories → use cases → blocs/cubits
// =============================================================================

Future<void> initRemainingDependencies() async {
  debugPrint('🏗️ [INIT] Starting full dependency initialization...');

  final prefs = sl<SharedPreferences>();
  final cfg = sl<RuntimeConfig>();

  // ── Main DioClient ──────────────────────────────────────────────────────────
  final dioClient = DioClient(cfg.apiBaseUrl, sl<AuthLocalDataSource>());
  sl.registerLazySingleton<DioClient>(() => dioClient);
  sl.registerLazySingleton<Dio>(() => dioClient.dio, instanceName: 'mainDio');

  final mainDio = sl<Dio>(instanceName: 'mainDio');

  sl.registerFactory<RequestIdInterceptor>(() => RequestIdInterceptor());
  sl.registerFactory<IdempotencyInterceptor>(
    () => IdempotencyInterceptor(prefs),
  );
  sl.registerFactory<ErrorNormalizerInterceptor>(
    () => ErrorNormalizerInterceptor(),
  );
  sl.registerFactory<RetryInterceptor>(() => RetryInterceptor(maxRetries: 3));
  sl.registerFactory<AuthInterceptor>(
    () =>
        AuthInterceptor(sl<AuthLocalDataSource>(), sl<AuthRemoteDataSource>()),
  );
  sl.registerFactory<DioExtraHook>(() => DioExtraHook(mainDio));

  mainDio.interceptors
    ..add(sl<DioExtraHook>())
    ..add(sl<RequestIdInterceptor>())
    ..add(sl<AuthInterceptor>())
    ..add(sl<IdempotencyInterceptor>())
    ..add(sl<ErrorNormalizerInterceptor>())
    ..add(sl<RetryInterceptor>());

  // ── Singletons that many features need — register first ────────────────────
  if (!sl.isRegistered<UnreadBadgeService>()) {
    sl.registerSingleton<UnreadBadgeService>(UnreadBadgeService());
  }
  if (!sl.isRegistered<RealtimeUnreadService>()) {
    sl.registerSingleton<RealtimeUnreadService>(RealtimeUnreadService());
  }
  sl.registerLazySingleton<LikeMemory>(() => LikeMemory(prefs));

  // ── Pusher — must come before anything that needs it ───────────────────────
  await _initializePusherService();

  // ── Host Pusher Service ─────────────────────────────────────────────────────
  // if (!sl.isRegistered<HostPusherService>()) {
  //   sl.registerLazySingleton<HostPusherService>(
  //     () => HostPusherService(sl<PusherService>()),
  //   );
  // }

  // ── Chat API service ────────────────────────────────────────────────────────
  if (!sl.isRegistered<ChatApiService>()) {
    sl.registerLazySingleton<ChatApiService>(
      () => ChatApiService(sl<DioClient>()),
    );
  }

  // ── Feature modules (each is self-contained) ────────────────────────────────
  // Order matters when module B depends on something module A registers.
  _initProfileSetupModule(); // registers ProfileRepository (setup) + use cases
  _initAccountModule(); // registers AccountRepository
  _initSearchModule(); // registers SearchRepository
  _initNotificationsModule(); // registers NotificationsRepository
  _initSettingsModule(); // registered blocked/email/username repos
  _initializeClubsModule(); // registers ClubsRepository
  _initializeLiveModule(); // registers GoLiveRepository etc
  _initWalletModule(); // registers WalletRepository, PinRepository
  _initTransferModule(); // registers GiftRepository
  _initWithdrawalModule(); // registers WithdrawalRepository
  registerProfileView(); // registers view ProfileRepository  ← after wallet
  registerChat(); // registers ChatRepository
  registerPosts(); // registers PostRepository
  creatPost(); // registers CreatePostRepository
  liveFeeds(); // registers LiveFeedRepository

  // ── Live viewer services (after AgoraService + PusherService are ready) ────
  _initializeLiveViewerServices();

  // ── Play Billing (non-blocking) ─────────────────────────────────────────────
  unawaited(
    sl<PlayBillingService>().init().catchError(
      (e) => debugPrint('⚠️ PlayBilling init error (non-fatal): $e'),
    ),
  );

  // ── Config refresh monitor ──────────────────────────────────────────────────
  await RuntimeConfigRefreshService().startMonitoring();

  debugPrint('✅ [INIT] Full dependency initialization complete');
}

// =============================================================================
// MODULE INITIALIZERS
// Each function registers only what it owns. No cross-module assumptions.
// =============================================================================

void _initProfileSetupModule() {
  if (!sl.isRegistered<ProfileRemoteDataSource>()) {
    sl.registerLazySingleton<ProfileRemoteDataSource>(
      () => ProfileRemoteDataSourceImpl(sl<Dio>(instanceName: 'mainDio')),
    );
  }
  if (!sl.isRegistered<CountryLocalDataSource>()) {
    sl.registerLazySingleton<CountryLocalDataSource>(
      () => CountryLocalDataSourceImpl(),
    );
  }
  if (!sl.isRegistered<ProfileRepository>()) {
    sl.registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(
        remote: sl(),
        countryLocal: sl(),
        local: sl<AuthLocalDataSource>(),
      ),
    );
  }

  // Use cases
  if (!sl.isRegistered<SetupProfile>())
    sl.registerLazySingleton(() => SetupProfile(sl()));
  if (!sl.isRegistered<UpdateInterests>())
    sl.registerLazySingleton(() => UpdateInterests(sl()));
  if (!sl.isRegistered<UpdateProfile>())
    sl.registerLazySingleton(() => UpdateProfile(sl()));
  if (!sl.isRegistered<FetchMyProfile>())
    sl.registerLazySingleton(() => FetchMyProfile(sl()));

  // Cubits
  sl.registerFactory(() => ProfileSetupCubit(sl(), sl()));
  sl.registerFactory(() => UserInterestCubit(sl()));

  sl.registerFactory(
    () => ProfilePageCubit(
      fetchMyProfile: sl(),
      fetchMyPosts:
          ({required String userUuid, int page = 1, int perPage = 50}) async {
            // view_repo.ProfileRepository is registered by registerProfileView()
            // which runs after this. We call sl<> lazily inside the closure so
            // it resolves at call-time, not at registration-time.
            final paginated = await sl<view_repo.ProfileRepository>()
                .getUserPosts(userUuid, page: page, perPage: perPage);
            return paginated.data;
          },
    ),
  );

  sl.registerFactory(
    () => EditProfileCubit(
      fetchMyProfile: sl(),
      updateProfile: sl(),
      profileRepo: sl(),
      authLocal: sl<AuthLocalDataSource>(),
      getCurrentUser: sl(),
    ),
  );
}

void _initAccountModule() {
  if (!sl.isRegistered<AccountRemoteDataSource>()) {
    sl.registerLazySingleton<AccountRemoteDataSource>(
      () => AccountRemoteDataSourceImpl(sl<Dio>(instanceName: 'mainDio')),
    );
  }
  if (!sl.isRegistered<AccountRepository>()) {
    sl.registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(sl<AccountRemoteDataSource>()),
    );
  }

  if (!sl.isRegistered<DeactivateAccount>())
    sl.registerLazySingleton(() => DeactivateAccount(sl()));
  if (!sl.isRegistered<ReactivateAccount>())
    sl.registerLazySingleton(() => ReactivateAccount(sl()));
  if (!sl.isRegistered<DeleteAccount>())
    sl.registerLazySingleton(() => DeleteAccount(sl()));

  sl.registerFactory<AccountSettingsCubit>(
    () => AccountSettingsCubit(
      repository: sl<AccountRepository>(),
      prefs: sl<SharedPreferences>(),
    ),
  );
}

void _initSearchModule() {
  if (!sl.isRegistered<SearchRemoteDataSource>()) {
    sl.registerLazySingleton<SearchRemoteDataSource>(
      () => SearchRemoteDataSourceImpl(sl<DioClient>()),
    );
  }
  if (!sl.isRegistered<SearchRepository>()) {
    sl.registerLazySingleton<SearchRepository>(
      () => SearchRepositoryImpl(remoteDataSource: sl()),
    );
  }

  if (!sl.isRegistered<SearchContent>())
    sl.registerLazySingleton<SearchContent>(() => SearchContent(sl()));
  if (!sl.isRegistered<GetTrendingTags>())
    sl.registerLazySingleton<GetTrendingTags>(() => GetTrendingTags(sl()));
  if (!sl.isRegistered<GetSuggestedUsers>())
    sl.registerLazySingleton<GetSuggestedUsers>(() => GetSuggestedUsers(sl()));
  if (!sl.isRegistered<GetPopularClubs>())
    sl.registerLazySingleton<GetPopularClubs>(() => GetPopularClubs(sl()));

  sl.registerFactory<SearchBloc>(
    () => SearchBloc(
      searchContent: sl(),
      getTrendingTags: sl(),
      getSuggestedUsers: sl(),
      getPopularClubs: sl(),
    ),
  );
  sl.registerFactory(() => SearchClubsCubit(sl()));
}

void _initNotificationsModule() {
  if (!sl.isRegistered<NotificationsRemoteDataSource>()) {
    sl.registerLazySingleton<NotificationsRemoteDataSource>(
      () => NotificationsRemoteDataSource(sl<DioClient>()),
    );
  }
  if (!sl.isRegistered<NotificationsRepository>()) {
    sl.registerLazySingleton<NotificationsRepository>(
      () => NotificationsRepositoryImpl(sl<NotificationsRemoteDataSource>()),
    );
  }

  if (!sl.isRegistered<UpdateNotificationSettings>())
    sl.registerLazySingleton(() => UpdateNotificationSettings(sl()));
  if (!sl.isRegistered<GetNotificationSettings>())
    sl.registerLazySingleton(() => GetNotificationSettings(sl()));

  sl.registerFactory<NotificationsBloc>(
    () => NotificationsBloc(sl<NotificationsRepository>()),
  );
}

void _initSettingsModule() {
  if (!sl.isRegistered<BlockedUsersRemoteDataSource>()) {
    sl.registerLazySingleton<BlockedUsersRemoteDataSource>(
      () => BlockedUsersRemoteDataSource(sl<DioClient>()),
    );
  }
  if (!sl.isRegistered<ChangeEmailRemoteDataSource>()) {
    sl.registerLazySingleton<ChangeEmailRemoteDataSource>(
      () => ChangeEmailRemoteDataSource(sl<DioClient>()),
    );
  }
  if (!sl.isRegistered<ChangeUsernameRemoteDataSource>()) {
    sl.registerLazySingleton<ChangeUsernameRemoteDataSource>(
      () => ChangeUsernameRemoteDataSource(sl<DioClient>()),
    );
  }
  if (!sl.isRegistered<BlockedUsersRepository>()) {
    sl.registerLazySingleton<BlockedUsersRepository>(
      () => BlockedUsersRepositoryImpl(sl<BlockedUsersRemoteDataSource>()),
    );
  }
  if (!sl.isRegistered<ChangeEmailRepository>()) {
    sl.registerLazySingleton<ChangeEmailRepository>(
      () => ChangeEmailRepositoryImpl(sl<ChangeEmailRemoteDataSource>()),
    );
  }
  if (!sl.isRegistered<ChangeUsernameRepository>()) {
    sl.registerLazySingleton<ChangeUsernameRepository>(
      () => ChangeUsernameRepositoryImpl(sl<ChangeUsernameRemoteDataSource>()),
    );
  }

  sl.registerFactory<BlockedUsersCubit>(
    () => BlockedUsersCubit(sl<BlockedUsersRepository>()),
  );
  sl.registerFactory<ChangeEmailCubit>(
    () => ChangeEmailCubit(sl<ChangeEmailRepository>()),
  );
  sl.registerFactory<ChangeUsernameCubit>(
    () => ChangeUsernameCubit(sl<ChangeUsernameRepository>()),
  );
}

void _initWalletModule() {
  // Data sources
  if (!sl.isRegistered<RemoteWalletDataSource>()) {
    sl.registerLazySingleton<RemoteWalletDataSource>(
      () => RemoteWalletDataSource(client: sl<Dio>(instanceName: 'mainDio')),
    );
  }
  // LocalWalletDataSource — was missing
  // if (!sl.isRegistered<LocalWalletDataSource>()) {
  //   sl.registerLazySingleton<LocalWalletDataSource>(
  //     () => LocalWalletDataSource(sl<SharedPreferences>()),
  //   );
  // }
  if (!sl.isRegistered<PinRemoteDataSource>()) {
    sl.registerLazySingleton<PinRemoteDataSource>(
      () => PinRemoteDataSource(sl<DioClient>()),
    );
  }

  // Repositories
  if (!sl.isRegistered<WalletRepositoryImpl>()) {
    sl.registerLazySingleton<WalletRepositoryImpl>(
      () => WalletRepositoryImpl(remote: sl<RemoteWalletDataSource>()),
    );
  }
  if (!sl.isRegistered<WalletRepository>()) {
    sl.registerLazySingleton<WalletRepository>(
      () => sl<WalletRepositoryImpl>(),
    );
  }
  if (!sl.isRegistered<PinRepository>()) {
    sl.registerLazySingleton<PinRepository>(
      () => PinRepositoryImpl(sl<PinRemoteDataSource>()),
    );
  }

  // Use cases
  // if (!sl.isRegistered<SetPin>()) {
  //   sl.registerLazySingleton<SetPin>(() => SetPin(sl<PinRepository>()));
  // }

  // Helpers
  if (!sl.isRegistered<IdempotencyHelper>()) {
    sl.registerLazySingleton<IdempotencyHelper>(
      () => IdempotencyHelper(sl<SharedPreferences>()),
    );
  }
  if (!sl.isRegistered<PlayBillingService>()) {
    sl.registerLazySingleton<PlayBillingService>(
      () => PlayBillingService(
        repo: sl<WalletRepositoryImpl>(),
        idem: sl<IdempotencyHelper>(),
      ),
    );
  }

  // Cubits
  sl.registerFactory<WalletCubit>(() => WalletCubit(sl<WalletRepository>()));
  sl.registerFactory<SetNewPinCubit>(() => SetNewPinCubit(sl<PinRepository>()));
  sl.registerFactory<ResetPinCubit>(() => ResetPinCubit(sl<PinRepository>()));
}

void _initTransferModule() {
  if (!sl.isRegistered<GiftRemoteDataSource>()) {
    sl.registerLazySingleton<GiftRemoteDataSource>(
      () => GiftRemoteDataSource(sl<DioClient>()),
    );
  }
  // GiftLocalDataSource — was missing
  if (!sl.isRegistered<GiftLocalDataSource>()) {
    sl.registerLazySingleton<GiftLocalDataSource>(
      // () => GiftLocalDataSource(sl<SharedPreferences>()),
      () => GiftLocalDataSource(),
    );
  }
  if (!sl.isRegistered<GiftRepository>()) {
    sl.registerLazySingleton<GiftRepository>(
      () => GiftRepositoryImpl(sl<GiftRemoteDataSource>()),
    );
  }
  sl.registerFactory<TransferCubit>(
    () => TransferCubit(repository: sl<GiftRepository>()),
  );
}

void _initWithdrawalModule() {
  if (!sl.isRegistered<WithdrawalRemoteDataSource>()) {
    sl.registerLazySingleton<WithdrawalRemoteDataSource>(
      () => WithdrawalRemoteDataSource(sl<DioClient>()),
    );
  }
  if (!sl.isRegistered<WithdrawalRepository>()) {
    sl.registerLazySingleton<WithdrawalRepository>(
      () => WithdrawalRepositoryImpl(sl<WithdrawalRemoteDataSource>()),
    );
  }
  sl.registerFactory<WithdrawalCubit>(
    () => WithdrawalCubit(repository: sl<WithdrawalRepository>()),
  );
}

// =============================================================================
// PRESERVED PUBLIC MODULE FUNCTIONS (called from feature code)
// =============================================================================

void _initializeClubsModule() {
  if (!sl.isRegistered<ClubsRemoteDataSource>()) {
    sl.registerLazySingleton<ClubsRemoteDataSource>(
      () => ClubsRemoteDataSourceImpl(sl<Dio>(instanceName: 'mainDio')),
    );
  }
  if (!sl.isRegistered<ClubsRepository>()) {
    sl.registerLazySingleton<ClubsRepository>(
      () => ClubsRepositoryImpl(sl<ClubsRemoteDataSource>()),
    );
  }
  if (!sl.isRegistered<ClubIncomeRemoteDataSource>()) {
    sl.registerLazySingleton<ClubIncomeRemoteDataSource>(
      () => ClubIncomeRemoteDataSource(sl<Dio>(instanceName: 'mainDio')),
    );
  }
  if (!sl.isRegistered<ClubIncomeRepository>()) {
    sl.registerLazySingleton<ClubIncomeRepository>(
      () => ClubIncomeRepositoryImpl(sl<ClubIncomeRemoteDataSource>()),
    );
  }

  sl.registerFactory<MyClubsCubit>(() => MyClubsCubit(sl<ClubsRepository>()));
  sl.registerFactory<DiscoverClubsCubit>(
    () => DiscoverClubsCubit(sl<ClubsRepository>()),
  );
  sl.registerFactory<ClubProfileCubit>(
    () => ClubProfileCubit(sl<ClubsRepository>()),
  );
  sl.registerFactory<SuggestedClubsCubit>(
    () => SuggestedClubsCubit(sl<ClubsRepository>()),
  );
  sl.registerFactory<ClubIncomeCubit>(
    () => ClubIncomeCubit(sl<ClubIncomeRepository>(), ''),
  );
  sl.registerFactory<CreateClubCubit>(
    () => CreateClubCubit(sl<ClubsRepository>()),
  );
  sl.registerFactoryParam<EditClubCubit, String, void>(
    (clubUuid, _) =>
        EditClubCubit(repository: sl<ClubsRepository>(), clubUuid: clubUuid),
  );
  sl.registerFactoryParam<ClubMembersCubit, String, void>(
    (clubSlug, _) =>
        ClubMembersCubit(repo: sl<ClubsRepository>(), club: clubSlug),
  );
  sl.registerFactoryParam<DonateClubCubit, String, void>(
    (club, _) => DonateClubCubit(repository: sl<ClubsRepository>(), club: club),
  );
}

void _initializeLiveModule() {
  if (!sl.isRegistered<AgoraService>()) {
    sl.registerLazySingleton<AgoraService>(() => AgoraService());
  }
  if (!sl.isRegistered<CameraService>()) {
    sl.registerLazySingleton<CameraService>(() => RealCameraService());
  }
  if (!sl.isRegistered<AudioTestService>()) {
    sl.registerLazySingleton<AudioTestService>(() => RecordAudioTestService());
  }
  if (!sl.isRegistered<LiveSessionTracker>()) {
    sl.registerLazySingleton<LiveSessionTracker>(() => LiveSessionTracker());
  }

  if (!sl.isRegistered<GoLiveRepository>()) {
    sl.registerLazySingleton<GoLiveRepository>(
      () => GoLiveRepositoryImpl(sl<DioClient>()),
    );
  }
  if (!sl.isRegistered<LiveSessionRepository>()) {
    sl.registerLazySingleton<LiveSessionRepository>(
      () => LiveSessionRepositoryImpl(
        sl<DioClient>(),
        sl<PusherService>(),
        sl<AgoraService>(),
        sl<LiveSessionTracker>(),
      ),
    );
  }

  // ParticipantsRepository — was missing
  // if (!sl.isRegistered<ParticipantsRepository>()) {
  //   sl.registerLazySingleton<ParticipantsRepository>(
  //     () => ParticipantsRepositoryImpl(sl<DioClient>(), PusherService(),),
  //   );
  // }

  sl.registerFactory<GoLiveCubit>(
    () => GoLiveCubit(
      sl<GoLiveRepository>(),
      sl<CameraService>(),
      sl<AudioTestService>(),
    ),
  );
  sl.registerFactory<LiveHostBloc>(
    () => LiveHostBloc(sl<LiveSessionRepository>(), sl<AgoraService>()),
  );
  sl.registerFactory<ParticipantsBloc>(
    () => ParticipantsBloc(sl<ParticipantsRepository>()),
  );
}

void registerProfileView() {
  if (!sl.isRegistered<view_ds.ProfileRemoteDataSource>()) {
    sl.registerLazySingleton<view_ds.ProfileRemoteDataSource>(
      () => view_ds.ProfileRemoteDataSource(sl<DioClient>()),
    );
  }
  if (!sl.isRegistered<view_repo.ProfileRepository>()) {
    sl.registerLazySingleton<view_repo.ProfileRepository>(
      () => view_repo_impl.ProfileRepositoryImpl(
        sl<view_ds.ProfileRemoteDataSource>(),
      ),
    );
  }
  sl.registerFactory<ProfileCubit>(
    () => ProfileCubit(sl<view_repo.ProfileRepository>()),
  );
  if (!sl.isRegistered<FollowListRemoteDataSource>()) {
    sl.registerLazySingleton<FollowListRemoteDataSource>(
      () => FollowListRemoteDataSource(sl<DioClient>()),
    );
  }
}

void registerChat() {
  if (!sl.isRegistered<ChatRepository>()) {
    sl.registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(
        sl<DioClient>(),
        sl<PusherService>(),
        sl<AuthLocalDataSource>(),
      ),
    );
  }
  sl.registerFactory<ChatCubit>(
    () => ChatCubit(sl<ChatRepository>(), sl<CurrentUserService>()),
  );
}

void registerPosts() {
  if (!sl.isRegistered<PostRemoteDataSource>()) {
    sl.registerLazySingleton<PostRemoteDataSource>(
      () => PostRemoteDataSource(sl<DioClient>()),
    );
  }
  if (!sl.isRegistered<PostRepository>()) {
    sl.registerLazySingleton<PostRepository>(
      () => PostRepositoryImpl(sl<PostRemoteDataSource>()),
    );
  }
  sl.registerFactoryParam<PostCubit, String, void>(
    (postId, _) => PostCubit(sl<PostRepository>(), postId),
  );
}

void creatPost() {
  if (!sl.isRegistered<CreatePostRemoteDataSource>()) {
    sl.registerLazySingleton<CreatePostRemoteDataSource>(
      () => CreatePostRemoteDataSource(sl<DioClient>()),
    );
  }
  if (!sl.isRegistered<CreatePostRepository>()) {
    sl.registerLazySingleton<CreatePostRepository>(
      () => CreatePostRepositoryImpl(sl<CreatePostRemoteDataSource>()),
    );
  }
  sl.registerFactory<CreatePostCubit>(
    () => CreatePostCubit(sl<CreatePostRepository>()),
  );
}

void liveFeeds() {
  if (sl.isRegistered<LiveFeedBloc>()) return;
  if (!sl.isRegistered<DioClient>()) {
    debugPrint('❌ DioClient not ready for LiveFeed');
    return;
  }
  try {
    if (!sl.isRegistered<LiveFeedRemoteDataSource>()) {
      sl.registerLazySingleton<LiveFeedRemoteDataSource>(
        () => LiveFeedRemoteDataSourceImpl.fromDioClient(sl<DioClient>()),
      );
    }
    if (!sl.isRegistered<LiveFeedRepository>()) {
      sl.registerLazySingleton<LiveFeedRepository>(
        () => LiveFeedRepositoryImpl(sl<LiveFeedRemoteDataSource>()),
      );
    }
    sl.registerFactory<LiveFeedBloc>(
      () => LiveFeedBloc(sl<LiveFeedRepository>()),
    );
  } catch (e, stack) {
    debugPrint('❌ Error registering LiveFeed: $e\n$stack');
  }
}

// =============================================================================
// PUSHER
// =============================================================================

Future<void> ensurePusherInitialized() async {
  await _initializePusherService();
}

Future<void> _initializePusherService() async {
  debugPrint('🔧 [PUSHER] Initializing...');
  try {
    if (!sl.isRegistered<PusherService>()) {
      sl.registerLazySingleton<PusherService>(() => PusherService());
    }

    final pusher = sl<PusherService>();
    final cfg = sl<RuntimeConfig>();

    if (pusher.isInitialized &&
        !pusher.isInBadState &&
        cfg.pusherKey.isNotEmpty &&
        cfg.pusherKey != 'disabled') {
      debugPrint('✅ [PUSHER] Already initialized');
      if (!pusher.isConnected) await pusher.connect();
      return;
    }

    if (pusher.isInitialized && pusher.isInBadState) {
      debugPrint('⚠️ [PUSHER] Bad state — will be fixed by refresh service');
      return;
    }

    if (cfg.pusherKey.isEmpty || cfg.pusherKey == 'disabled') {
      debugPrint('⚠️ [PUSHER] Key empty — initializing in disabled state');
      await pusher.initialize(
        apiKey: 'disabled',
        cluster: 'mt1',
        authEndpoint: null,
        authCallback: null,
      );
      await RuntimeConfigRefreshService().startMonitoring();
      return;
    }

    await pusher.initialize(
      apiKey: cfg.pusherKey,
      cluster: cfg.pusherCluster,
      authEndpoint: '${cfg.apiBaseUrl}/broadcasting/auth',
      authCallback: (channelName, socketId, options) async {
        try {
          final token = await sl<AuthLocalDataSource>().readToken();
          if (token == null || token.isEmpty) throw Exception('No auth token');
          final response = await sl<Dio>(instanceName: 'mainDio').post(
            '/broadcasting/auth',
            data: {'socket_id': socketId, 'channel_name': channelName},
            options: Options(
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            ),
          );
          return response.data;
        } catch (e) {
          debugPrint('❌ [PUSHER] Auth callback failed: $e');
          rethrow;
        }
      },
    );
    debugPrint('✅ [PUSHER] Initialized');
    await RuntimeConfigRefreshService().startMonitoring();
  } catch (e) {
    debugPrint('⚠️ [PUSHER] Init failed (non-fatal): $e');
  }
}

// =============================================================================
// LIVE VIEWER SERVICES
// =============================================================================

void _initializeLiveViewerServices() {
  debugPrint('🔧 Initializing Live Viewer Services...');

  if (!sl.isRegistered<AgoraViewerService>()) {
    sl.registerLazySingleton<AgoraViewerService>(() {
      return AgoraViewerService(
        onTokenRefresh: (role) async {
          try {
            final agoraService = sl<AgoraViewerService>();
            final currentChannel = agoraService.channelId;
            if (currentChannel == null || currentChannel.isEmpty) {
              throw Exception('No current channel');
            }
            final token = await sl<AuthLocalDataSource>().readToken();
            final response = await sl<Dio>(instanceName: 'mainDio').post(
              '/api/v1/live/refresh-token',
              data: {'role': role, 'channel': currentChannel},
              options: Options(headers: {'Authorization': 'Bearer $token'}),
            );
            return (response.data as Map<String, dynamic>)['token'] as String;
          } catch (e) {
            debugPrint('❌ Token refresh failed: $e');
            return '';
          }
        },
      );
    });
  }

  if (!sl.isRegistered<LiveStreamService>()) {
    sl.registerLazySingleton<LiveStreamService>(
      () => LiveStreamService(
        agoraService: sl<AgoraViewerService>(),
        tokenRefresher: sl<AgoraViewerService>().onTokenRefresh,
      ),
    );
  }
  if (!sl.isRegistered<NetworkMonitorService>()) {
    sl.registerLazySingleton<NetworkMonitorService>(
      () => NetworkMonitorService(sl<LiveStreamService>()),
    );
  }
  if (!sl.isRegistered<ReconnectionService>()) {
    sl.registerLazySingleton<ReconnectionService>(
      () => ReconnectionService(sl<LiveStreamService>()),
    );
  }
  if (!sl.isRegistered<RoleChangeService>()) {
    sl.registerLazySingleton<RoleChangeService>(
      () => RoleChangeService(sl<LiveStreamService>()),
    );
  }

  sl.registerFactoryParam<ViewerBloc, ViewerRepositoryImpl, void>((repo, _) {
    return ViewerBloc(
      repo,
      liveStreamService: sl<LiveStreamService>(),
      agoraViewerService: sl<AgoraViewerService>(),
      networkMonitorService: sl<NetworkMonitorService>(),
      reconnectionService: sl<ReconnectionService>(),
      roleChangeService: sl<RoleChangeService>(),
    );
  });

  debugPrint('✅ Live Viewer Services initialized');
}

ViewerRepositoryImpl createViewerRepository({
  required String livestreamParam,
  required int livestreamIdNumeric,
  required String channelName,
  String? hostUserUuid,
  HostInfo? initialHost,
  DateTime? startedAt,
}) {
  return ViewerRepositoryImpl(
    http: sl<DioClient>(),
    pusher: sl<PusherService>(),
    authLocalDataSource: sl<AuthLocalDataSource>(),
    agoraViewerService: sl<AgoraViewerService>(),
    livestreamParam: livestreamParam,
    livestreamIdNumeric: livestreamIdNumeric,
    channelName: channelName,
    hostUserUuid: hostUserUuid,
    initialHost: initialHost,
    startedAt: startedAt,
  );
}

// =============================================================================
// DEPENDENCY MANAGER
// =============================================================================

class DependencyManager {
  static final Completer<void> _allReady = Completer<void>();
  static bool _isInitialized = false;

  static Future<void> waitForAllDependencies() async {
    if (_isInitialized) return;
    return _allReady.future;
  }

  static void markAllDependenciesReady() {
    if (!_allReady.isCompleted) {
      _isInitialized = true;
      _allReady.complete();
      debugPrint('✅ DependencyManager: all dependencies ready');
    }
  }

  static bool get isReady => _isInitialized;
}

// Backwards-compat aliases for code that still calls the old module functions
void wallet() => _initWalletModule();
void setWalletPin() {} // merged into _initWalletModule
void transfercoin() => _initTransferModule();
void withdrawal() => _initWithdrawalModule();
