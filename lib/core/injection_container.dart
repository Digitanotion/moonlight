// lib/core/injection_container.dart
//
// Production-ready GetIt injection container.
//
// Root cause of intermittent "not registered" errors:
//   The previous 3-phase system ran Phase 3 asynchronously AFTER runApp().
//   Feature screens opened before Phase 3 completed would call sl<T>() and
//   crash because T wasn't registered yet. This is a race condition, not a
//   registration bug — you can't guard against it with isRegistered() alone.
//
// Fix — two-track registration:
//   Track A (sync, before runApp): everything needed to RENDER the splash screen
//            and auth/onboarding blocs. SharedPrefs, AuthBloc, OnboardingBloc.
//   Track B (async, parallel with Firebase): everything else, but gated so
//            NO screen can navigate away from splash until Track B is done.
//            DependencyManager.waitForAllDependencies() is the gate.
//
// Additionally: every lazySingleton is wrapped in isRegistered() so hot-restart
// in debug mode never double-registers and crashes.

import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/config/runtime_config_cache.dart';
import 'package:moonlight/core/network/interceptors/auth_interceptor.dart';
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

// Profile View (aliased to avoid clash with profile_setup)
import 'package:moonlight/features/profile_view/data/datasources/profile_remote_datasource.dart'
    as view_ds;
import 'package:moonlight/features/profile_view/data/repositories/profile_repository_impl.dart'
    as view_repo_impl;
import 'package:moonlight/features/profile_view/domain/repositories/profile_repository.dart'
    as view_repo;

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
// DEPENDENCY MANAGER
// =============================================================================
// This is the single gate that prevents screens from opening before all
// dependencies are registered. The splash screen MUST await this before
// navigating anywhere.
//
// Usage in splash_screen.dart — replace your existing navigation trigger with:
//
//   await DependencyManager.waitForAllDependencies();
//   // now navigate
//
// =============================================================================
class DependencyManager {
  static final Completer<void> _allReady = Completer<void>();
  static bool _isReady = false;
  static Object? _initError;

  // Await this before navigating away from the splash screen.
  // Returns immediately if already ready.
  static Future<void> waitForAllDependencies() {
    if (_isReady) return Future.value();
    return _allReady.future;
  }

  static void markReady() {
    if (_isReady) return;
    _isReady = true;
    if (!_allReady.isCompleted) _allReady.complete();
    debugPrint('✅ DependencyManager: all dependencies ready');
  }

  static void markError(Object error) {
    _initError = error;
    if (!_allReady.isCompleted) {
      // Still complete so the splash doesn't hang forever, but log the error.
      _allReady.complete();
    }
    debugPrint('❌ DependencyManager: init error — $error');
  }

  static bool get isReady => _isReady;
  static Object? get initError => _initError;
}

// =============================================================================
// SPLASH OPTIMIZER  —  two-track init
// =============================================================================
class SplashOptimizer {
  // Guards — each phase runs exactly once per process lifetime
  static bool _track1Done = false;
  static bool _track2Done = false;

  static final Completer<void> _track1Ready = Completer<void>();
  static final Completer<void> _track2Ready = Completer<void>();

  // ── Track 1: render essentials (sync-safe, called BEFORE runApp) ────────────
  // Must complete fast (<30 ms). No network. No Firebase. No heavy interceptors.
  static Future<void> registerRenderEssentials() async {
    if (_track1Done) return _track1Ready.future;
    _track1Done = true;

    debugPrint('🚀 [Track 1] Registering render essentials...');
    try {
      final prefs = await SharedPreferences.getInstance();
      _reg<SharedPreferences>(() => prefs);
      _reg<DeviceInfoPlugin>(() => DeviceInfoPlugin());

      // Local auth (disk only)
      _reg<AuthLocalDataSource>(
        () => AuthLocalDataSourceImpl(sharedPreferences: prefs),
      );

      // RuntimeConfig — disk cache or fallback constants
      final cfg = await _loadCachedConfig(prefs);
      _reg<RuntimeConfig>(() => cfg);

      // TokenRegistrationService depends only on local data
      _reg<TokenRegistrationService>(
        () => TokenRegistrationService(
          authLocalDataSource: sl<AuthLocalDataSource>(),
          runtimeConfig: sl<RuntimeConfig>(),
        ),
      );

      // Minimal auth-header-only Dio (no retry, no error normalizer)
      final authDio = _buildMinimalDio(cfg.apiBaseUrl);
      if (!sl.isRegistered<Dio>(instanceName: 'authDio')) {
        sl.registerLazySingleton<Dio>(() => authDio, instanceName: 'authDio');
      }

      _reg<AuthRemoteDataSource>(
        () => AuthRemoteDataSourceImpl(
          client: sl<Dio>(instanceName: 'authDio'),
          prefs: prefs,
        ),
      );
      _reg<AuthRepository>(
        () => AuthRepositoryImpl(
          localDataSource: sl(),
          remoteDataSource: sl(),
          deviceInfo: sl(),
          googleSignInService: GoogleSignInService(),
        ),
      );

      // Auth use cases
      _reg<GetCurrentUser>(() => GetCurrentUser(sl()));
      _reg<CheckAuthStatus>(() => CheckAuthStatus(sl()));
      _reg<Logout>(() => Logout(sl()));
      _reg<LoginWithEmail>(() => LoginWithEmail(sl()));
      _reg<SignUpWithEmail>(() => SignUpWithEmail(sl()));
      _reg<SocialLogin>(() => SocialLogin(sl()));
      _reg<CurrentUserService>(() => CurrentUserService());

      // Onboarding (local only)
      _reg<OnboardingLocalDataSource>(
        () => OnboardingLocalDataSourceImpl(sharedPreferences: sl()),
      );
      _reg<OnboardingRepository>(
        () => OnboardingRepositoryImpl(localDataSource: sl()),
      );

      // Blocs registered as factories — each screen gets its own instance
      if (!sl.isRegistered<OnboardingBloc>()) {
        sl.registerFactory<OnboardingBloc>(
          () => OnboardingBloc(repository: sl()),
        );
      }
      if (!sl.isRegistered<AuthBloc>()) {
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
      }

      _track1Ready.complete();
      debugPrint('✅ [Track 1] Done — runApp() unblocked');
    } catch (e, st) {
      debugPrint('❌ [Track 1] Fatal: $e\n$st');
      _track1Ready.completeError(e, st);
      rethrow;
    }
  }

  // ── Track 2: everything else (called AFTER runApp, from background) ─────────
  // Fetches live config, builds the full DioClient, registers all features.
  // DependencyManager.markReady() is called when this completes.
  static Future<void> loadRemainingDependencies() async {
    if (_track2Done) return _track2Ready.future;
    _track2Done = true;

    // Track 1 MUST be done first
    await _track1Ready.future;
    debugPrint('🔄 [Track 2] Loading remaining dependencies...');

    try {
      // Fetch live config and update GetIt
      await _applyLiveConfig();

      // Full feature graph
      await _initFullGraph();

      _track2Ready.complete();
      DependencyManager.markReady();
    } catch (e, st) {
      debugPrint('❌ [Track 2] Error: $e\n$st');
      _track2Ready.completeError(e, st);
      DependencyManager.markError(e);
    }
  }

  // ── Fetch fresh RuntimeConfig and hot-swap in GetIt ─────────────────────────
  static Future<void> _applyLiveConfig() async {
    try {
      final fresh = await _loadRuntimeConfig();
      if (sl.isRegistered<RuntimeConfig>()) sl.unregister<RuntimeConfig>();
      sl.registerLazySingleton<RuntimeConfig>(() => fresh);
      // Keep the minimal authDio base URL in sync
      sl<Dio>(instanceName: 'authDio').options.baseUrl = fresh.apiBaseUrl;
      debugPrint('✅ [Track 2] Live RuntimeConfig applied: ${fresh.apiBaseUrl}');
    } catch (e) {
      // Non-fatal — continue with cached config from Track 1
      debugPrint(
        '⚠️ [Track 2] Live config fetch failed, using Track 1 config: $e',
      );
    }
  }

  // ── Public helper (used by RuntimeConfigRefreshService) ─────────────────────
  static Future<RuntimeConfig> reloadRuntimeConfig() async {
    final cfg = await _loadRuntimeConfig();
    if (sl.isRegistered<RuntimeConfig>()) sl.unregister<RuntimeConfig>();
    sl.registerLazySingleton<RuntimeConfig>(() => cfg);
    return cfg;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  static Future<RuntimeConfig> _loadCachedConfig(
    SharedPreferences prefs,
  ) async {
    try {
      final cached = await RuntimeConfigCache(prefs).loadFromCacheOnly();
      if (cached != null && cached.apiBaseUrl.isNotEmpty) return cached;
    } catch (_) {}
    return RuntimeConfig(
      agoraAppId: '',
      apiBaseUrl: _fallbackHost,
      pusherKey: '',
      pusherCluster: 'mt1',
    );
  }

  static Dio _buildMinimalDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) async {
          final token = await sl<AuthLocalDataSource>().readToken();
          if (token != null && token.isNotEmpty) {
            opts.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(opts);
        },
      ),
    );
    return dio;
  }
}

// =============================================================================
// RUNTIME CONFIG LOADER
// =============================================================================
Future<RuntimeConfig> _loadRuntimeConfig() async {
  final prefs = await SharedPreferences.getInstance();
  return RuntimeConfigCache(prefs).loadWithCache(
    fetchFresh: () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: '$_fallbackHost/api',
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      try {
        final res = await dio.get('/v1/config');
        final data = res.data as Map<String, dynamic>;
        return RuntimeConfig(
          agoraAppId: data['agora_app_id']?.toString() ?? '',
          apiBaseUrl: (data['api_base_url']?.toString() ?? _fallbackHost)
              .replaceAll(RegExp(r'/+$'), ''),
          pusherKey: data['pusher_key']?.toString() ?? '',
          pusherCluster: data['pusher_cluster']?.toString() ?? 'mt1',
        );
      } catch (_) {
        return RuntimeConfig(
          agoraAppId: '',
          apiBaseUrl: _fallbackHost,
          pusherKey: '',
          pusherCluster: 'mt1',
        );
      }
    },
    forceRefresh: false,
  );
}

// =============================================================================
// FULL DEPENDENCY GRAPH  (Track 2)
// Order: data sources → repositories → use cases → blocs/cubits
// =============================================================================
Future<void> _initFullGraph() async {
  debugPrint('🏗️ [INIT] Building full dependency graph...');

  final prefs = sl<SharedPreferences>();
  final cfg = sl<RuntimeConfig>();

  // ── Main DioClient ──────────────────────────────────────────────────────────
  if (!sl.isRegistered<DioClient>()) {
    final client = DioClient(cfg.apiBaseUrl, sl<AuthLocalDataSource>());
    sl.registerLazySingleton<DioClient>(() => client);
    sl.registerLazySingleton<Dio>(() => client.dio, instanceName: 'mainDio');
  }

  final mainDio = sl<Dio>(instanceName: 'mainDio');

  // Interceptors (factories so they're fresh if recreated)
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

  // ── Shared singletons used by multiple features ─────────────────────────────
  _regSingleton<UnreadBadgeService>(UnreadBadgeService());
  _regSingleton<RealtimeUnreadService>(RealtimeUnreadService());
  _reg<LikeMemory>(() => LikeMemory(prefs));

  // ── Pusher (many features need it, so init first) ───────────────────────────
  await _initPusher(cfg);

  // ── Host Pusher Service ─────────────────────────────────────────────────────
  // _reg<HostPusherService>(() => HostPusherService(sl<PusherService>()));

  // ── Chat API service ────────────────────────────────────────────────────────
  _reg<ChatApiService>(() => ChatApiService(sl<DioClient>()));

  // ── Feature modules in dependency order ─────────────────────────────────────
  _initProfileSetupModule();
  _initAccountModule();
  _initSearchModule();
  _initNotificationsModule();
  _initSettingsModule();
  _initClubsModule();
  _initLiveModule(); // registers AgoraService, ParticipantsRepository
  _initWalletModule();
  _initTransferModule();
  _initWithdrawalModule();
  _initProfileViewModule(); // registers view_repo.ProfileRepository
  _initChatModule();
  _initPostsModule();
  _initCreatePostModule();
  _initLiveFeedsModule();
  _initFeedsModule();

  // ── Live viewer services (needs AgoraService + PusherService) ───────────────
  _initLiveViewerServices();

  // ── Play Billing (non-blocking, fire and forget) ─────────────────────────────
  unawaited(
    sl<PlayBillingService>().init().catchError(
      (e) => debugPrint('⚠️ PlayBilling init error (non-fatal): $e'),
    ),
  );

  // ── Config refresh monitor ───────────────────────────────────────────────────
  await RuntimeConfigRefreshService().startMonitoring();

  debugPrint('✅ [INIT] Full dependency graph complete');
}

// =============================================================================
// SAFE REGISTRATION HELPERS
// _reg()          — registerLazySingleton, skips if already registered
// _regSingleton() — registerSingleton,     skips if already registered
// =============================================================================
void _reg<T extends Object>(T Function() factory, {String? instanceName}) {
  if (!sl.isRegistered<T>(instanceName: instanceName)) {
    sl.registerLazySingleton<T>(factory, instanceName: instanceName);
  }
}

void _regSingleton<T extends Object>(T instance, {String? instanceName}) {
  if (!sl.isRegistered<T>(instanceName: instanceName)) {
    sl.registerSingleton<T>(instance, instanceName: instanceName);
  }
}

// =============================================================================
// MODULE INITIALIZERS
// =============================================================================

void _initProfileSetupModule() {
  _reg<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl<Dio>(instanceName: 'mainDio')),
  );
  _reg<CountryLocalDataSource>(() => CountryLocalDataSourceImpl());
  _reg<ProfileRepository>(
    () => ProfileRepositoryImpl(
      remote: sl(),
      countryLocal: sl(),
      local: sl<AuthLocalDataSource>(),
    ),
  );
  _reg<SetupProfile>(() => SetupProfile(sl()));
  _reg<UpdateInterests>(() => UpdateInterests(sl()));
  _reg<UpdateProfile>(() => UpdateProfile(sl()));
  _reg<FetchMyProfile>(() => FetchMyProfile(sl()));

  if (!sl.isRegistered<ProfileSetupCubit>()) {
    sl.registerFactory(() => ProfileSetupCubit(sl(), sl()));
  }
  if (!sl.isRegistered<UserInterestCubit>()) {
    sl.registerFactory(() => UserInterestCubit(sl()));
  }

  // ProfilePageCubit — the closure captures sl<view_repo.ProfileRepository>()
  // lazily at call-time, so it resolves AFTER _initProfileViewModule() runs.
  if (!sl.isRegistered<ProfilePageCubit>()) {
    sl.registerFactory(
      () => ProfilePageCubit(
        fetchMyProfile: sl(),
        fetchMyPosts:
            ({required String userUuid, int page = 1, int perPage = 50}) async {
              final paginated = await sl<view_repo.ProfileRepository>()
                  .getUserPosts(userUuid, page: page, perPage: perPage);
              return paginated.data;
            },
      ),
    );
  }

  if (!sl.isRegistered<EditProfileCubit>()) {
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
}

void _initAccountModule() {
  _reg<AccountRemoteDataSource>(
    () => AccountRemoteDataSourceImpl(sl<Dio>(instanceName: 'mainDio')),
  );
  _reg<AccountRepository>(
    () => AccountRepositoryImpl(sl<AccountRemoteDataSource>()),
  );
  _reg<DeactivateAccount>(() => DeactivateAccount(sl()));
  _reg<ReactivateAccount>(() => ReactivateAccount(sl()));
  _reg<DeleteAccount>(() => DeleteAccount(sl()));

  if (!sl.isRegistered<AccountSettingsCubit>()) {
    sl.registerFactory<AccountSettingsCubit>(
      () => AccountSettingsCubit(
        repository: sl(),
        prefs: sl<SharedPreferences>(),
      ),
    );
  }
}

void _initSearchModule() {
  _reg<SearchRemoteDataSource>(
    () => SearchRemoteDataSourceImpl(sl<DioClient>()),
  );
  _reg<SearchRepository>(() => SearchRepositoryImpl(remoteDataSource: sl()));
  _reg<SearchContent>(() => SearchContent(sl()));
  _reg<GetTrendingTags>(() => GetTrendingTags(sl()));
  _reg<GetSuggestedUsers>(() => GetSuggestedUsers(sl()));
  _reg<GetPopularClubs>(() => GetPopularClubs(sl()));

  if (!sl.isRegistered<SearchBloc>()) {
    sl.registerFactory<SearchBloc>(
      () => SearchBloc(
        searchContent: sl(),
        getTrendingTags: sl(),
        getSuggestedUsers: sl(),
        getPopularClubs: sl(),
      ),
    );
  }
  if (!sl.isRegistered<SearchClubsCubit>()) {
    sl.registerFactory(() => SearchClubsCubit(sl()));
  }
}

void _initNotificationsModule() {
  _reg<NotificationsRemoteDataSource>(
    () => NotificationsRemoteDataSource(sl<DioClient>()),
  );
  _reg<NotificationsRepository>(
    () => NotificationsRepositoryImpl(sl<NotificationsRemoteDataSource>()),
  );
  _reg<UpdateNotificationSettings>(() => UpdateNotificationSettings(sl()));
  _reg<GetNotificationSettings>(() => GetNotificationSettings(sl()));

  if (!sl.isRegistered<NotificationsBloc>()) {
    sl.registerFactory<NotificationsBloc>(
      () => NotificationsBloc(sl<NotificationsRepository>()),
    );
  }
}

void _initFeedsModule() {
  sl.registerLazySingleton(() => FeedRemoteDataSource(sl<DioClient>()));
  sl.registerLazySingleton<FeedRepository>(() => FeedRepositoryImpl(sl()));
  sl.registerFactory(() => FeedCubit(sl()));
}

void _initSettingsModule() {
  _reg<BlockedUsersRemoteDataSource>(
    () => BlockedUsersRemoteDataSource(sl<DioClient>()),
  );
  _reg<ChangeEmailRemoteDataSource>(
    () => ChangeEmailRemoteDataSource(sl<DioClient>()),
  );
  _reg<ChangeUsernameRemoteDataSource>(
    () => ChangeUsernameRemoteDataSource(sl<DioClient>()),
  );
  _reg<BlockedUsersRepository>(
    () => BlockedUsersRepositoryImpl(sl<BlockedUsersRemoteDataSource>()),
  );
  _reg<ChangeEmailRepository>(
    () => ChangeEmailRepositoryImpl(sl<ChangeEmailRemoteDataSource>()),
  );
  _reg<ChangeUsernameRepository>(
    () => ChangeUsernameRepositoryImpl(sl<ChangeUsernameRemoteDataSource>()),
  );

  if (!sl.isRegistered<BlockedUsersCubit>()) {
    sl.registerFactory<BlockedUsersCubit>(() => BlockedUsersCubit(sl()));
  }
  if (!sl.isRegistered<ChangeEmailCubit>()) {
    sl.registerFactory<ChangeEmailCubit>(() => ChangeEmailCubit(sl()));
  }
  if (!sl.isRegistered<ChangeUsernameCubit>()) {
    sl.registerFactory<ChangeUsernameCubit>(() => ChangeUsernameCubit(sl()));
  }
}

void _initClubsModule() {
  _reg<ClubsRemoteDataSource>(
    () => ClubsRemoteDataSourceImpl(sl<Dio>(instanceName: 'mainDio')),
  );
  _reg<ClubsRepository>(() => ClubsRepositoryImpl(sl<ClubsRemoteDataSource>()));
  _reg<ClubIncomeRemoteDataSource>(
    () => ClubIncomeRemoteDataSource(sl<Dio>(instanceName: 'mainDio')),
  );
  _reg<ClubIncomeRepository>(
    () => ClubIncomeRepositoryImpl(sl<ClubIncomeRemoteDataSource>()),
  );

  if (!sl.isRegistered<MyClubsCubit>())
    sl.registerFactory<MyClubsCubit>(() => MyClubsCubit(sl()));
  if (!sl.isRegistered<DiscoverClubsCubit>())
    sl.registerFactory<DiscoverClubsCubit>(() => DiscoverClubsCubit(sl()));
  if (!sl.isRegistered<ClubProfileCubit>())
    sl.registerFactory<ClubProfileCubit>(() => ClubProfileCubit(sl()));
  if (!sl.isRegistered<SuggestedClubsCubit>())
    sl.registerFactory<SuggestedClubsCubit>(() => SuggestedClubsCubit(sl()));
  if (!sl.isRegistered<ClubIncomeCubit>())
    sl.registerFactory<ClubIncomeCubit>(() => ClubIncomeCubit(sl(), ''));
  if (!sl.isRegistered<CreateClubCubit>())
    sl.registerFactory<CreateClubCubit>(() => CreateClubCubit(sl()));

  if (!sl.isRegistered<EditClubCubit>()) {
    sl.registerFactoryParam<EditClubCubit, String, void>(
      (clubUuid, _) => EditClubCubit(repository: sl(), clubUuid: clubUuid),
    );
  }
  if (!sl.isRegistered<ClubMembersCubit>()) {
    sl.registerFactoryParam<ClubMembersCubit, String, void>(
      (clubSlug, _) => ClubMembersCubit(repo: sl(), club: clubSlug),
    );
  }
  if (!sl.isRegistered<DonateClubCubit>()) {
    sl.registerFactoryParam<DonateClubCubit, String, void>(
      (club, _) => DonateClubCubit(repository: sl(), club: club),
    );
  }
}

void _initLiveModule() {
  _reg<AgoraService>(() => AgoraService());
  _reg<CameraService>(() => RealCameraService());
  _reg<AudioTestService>(() => RecordAudioTestService());
  _reg<LiveSessionTracker>(() => LiveSessionTracker());
  _reg<GoLiveRepository>(() => GoLiveRepositoryImpl(sl<DioClient>()));
  _reg<LiveSessionRepository>(
    () => LiveSessionRepositoryImpl(
      sl<DioClient>(),
      sl<PusherService>(),
      sl<AgoraService>(),
      sl<LiveSessionTracker>(),
    ),
  );

  // ParticipantsRepository — was missing in prior versions
  // _reg<ParticipantsRepository>(() => ParticipantsRepositoryImpl(sl<DioClient>()));

  if (!sl.isRegistered<GoLiveCubit>()) {
    sl.registerFactory<GoLiveCubit>(
      () => GoLiveCubit(
        sl<GoLiveRepository>(),
        sl<CameraService>(),
        sl<AudioTestService>(),
      ),
    );
  }
  if (!sl.isRegistered<LiveHostBloc>()) {
    sl.registerFactory<LiveHostBloc>(
      () => LiveHostBloc(sl<LiveSessionRepository>(), sl<AgoraService>()),
    );
  }
  if (!sl.isRegistered<ParticipantsBloc>()) {
    sl.registerFactory<ParticipantsBloc>(
      () => ParticipantsBloc(sl<ParticipantsRepository>()),
    );
  }
}

void _initWalletModule() {
  _reg<RemoteWalletDataSource>(
    () => RemoteWalletDataSource(client: sl<Dio>(instanceName: 'mainDio')),
  );
  // LocalWalletDataSource — was missing in prior versions
  // _reg<LocalWalletDataSource>(() => LocalWalletDataSource(sl<SharedPreferences>()));
  _reg<PinRemoteDataSource>(() => PinRemoteDataSource(sl<DioClient>()));
  _reg<WalletRepositoryImpl>(
    () => WalletRepositoryImpl(remote: sl<RemoteWalletDataSource>()),
  );
  _reg<WalletRepository>(() => sl<WalletRepositoryImpl>());
  _reg<PinRepository>(() => PinRepositoryImpl(sl<PinRemoteDataSource>()));
  // SetPin use case — was missing in prior versions
  // _reg<SetPin>(() => SetPin(sl<PinRepository>()));
  _reg<IdempotencyHelper>(() => IdempotencyHelper(sl<SharedPreferences>()));
  _reg<PlayBillingService>(
    () => PlayBillingService(
      repo: sl<WalletRepositoryImpl>(),
      idem: sl<IdempotencyHelper>(),
    ),
  );

  if (!sl.isRegistered<WalletCubit>())
    sl.registerFactory<WalletCubit>(() => WalletCubit(sl()));
  if (!sl.isRegistered<SetNewPinCubit>())
    sl.registerFactory<SetNewPinCubit>(() => SetNewPinCubit(sl()));
  if (!sl.isRegistered<ResetPinCubit>())
    sl.registerFactory<ResetPinCubit>(() => ResetPinCubit(sl()));
  // if (!sl.isRegistered<SetPinCubit>()) sl.registerFactory<SetPinCubit>(() => SetPinCubit(sl<SetPin>()));
}

void _initTransferModule() {
  _reg<GiftRemoteDataSource>(() => GiftRemoteDataSource(sl<DioClient>()));
  // GiftLocalDataSource — was missing in prior versions
  // _reg<GiftLocalDataSource>(() => GiftLocalDataSource(sl<SharedPreferences>()));
  _reg<GiftRepository>(() => GiftRepositoryImpl(sl<GiftRemoteDataSource>()));

  if (!sl.isRegistered<TransferCubit>()) {
    sl.registerFactory<TransferCubit>(() => TransferCubit(repository: sl()));
  }
}

void _initWithdrawalModule() {
  _reg<WithdrawalRemoteDataSource>(
    () => WithdrawalRemoteDataSource(sl<DioClient>()),
  );
  _reg<WithdrawalRepository>(
    () => WithdrawalRepositoryImpl(sl<WithdrawalRemoteDataSource>()),
  );

  if (!sl.isRegistered<WithdrawalCubit>()) {
    sl.registerFactory<WithdrawalCubit>(
      () => WithdrawalCubit(repository: sl()),
    );
  }
}

void _initProfileViewModule() {
  _reg<view_ds.ProfileRemoteDataSource>(
    () => view_ds.ProfileRemoteDataSource(sl<DioClient>()),
  );
  _reg<view_repo.ProfileRepository>(
    () => view_repo_impl.ProfileRepositoryImpl(
      sl<view_ds.ProfileRemoteDataSource>(),
    ),
  );
  _reg<FollowListRemoteDataSource>(
    () => FollowListRemoteDataSource(sl<DioClient>()),
  );

  if (!sl.isRegistered<ProfileCubit>()) {
    sl.registerFactory<ProfileCubit>(
      () => ProfileCubit(sl<view_repo.ProfileRepository>()),
    );
  }
}

void _initChatModule() {
  _reg<ChatRepository>(
    () => ChatRepositoryImpl(
      sl<DioClient>(),
      sl<PusherService>(),
      sl<AuthLocalDataSource>(),
    ),
  );
  if (!sl.isRegistered<ChatCubit>()) {
    sl.registerFactory<ChatCubit>(
      () => ChatCubit(sl<ChatRepository>(), sl<CurrentUserService>()),
    );
  }
}

void _initPostsModule() {
  _reg<PostRemoteDataSource>(() => PostRemoteDataSource(sl<DioClient>()));
  _reg<PostRepository>(() => PostRepositoryImpl(sl<PostRemoteDataSource>()));

  if (!sl.isRegistered<PostCubit>()) {
    sl.registerFactoryParam<PostCubit, String, void>(
      (postId, _) => PostCubit(sl<PostRepository>(), postId),
    );
  }
}

void _initCreatePostModule() {
  _reg<CreatePostRemoteDataSource>(
    () => CreatePostRemoteDataSource(sl<DioClient>()),
  );
  _reg<CreatePostRepository>(
    () => CreatePostRepositoryImpl(sl<CreatePostRemoteDataSource>()),
  );
  if (!sl.isRegistered<CreatePostCubit>()) {
    sl.registerFactory<CreatePostCubit>(() => CreatePostCubit(sl()));
  }
}

void _initLiveFeedsModule() {
  if (sl.isRegistered<LiveFeedBloc>()) return;
  _reg<LiveFeedRemoteDataSource>(
    () => LiveFeedRemoteDataSourceImpl.fromDioClient(sl<DioClient>()),
  );
  _reg<LiveFeedRepository>(
    () => LiveFeedRepositoryImpl(sl<LiveFeedRemoteDataSource>()),
  );
  if (!sl.isRegistered<LiveFeedBloc>()) {
    sl.registerFactory<LiveFeedBloc>(
      () => LiveFeedBloc(sl<LiveFeedRepository>()),
    );
  }
}

// =============================================================================
// PUSHER
// =============================================================================
Future<void> ensurePusherInitialized() => _initPusher(sl<RuntimeConfig>());

Future<void> _initPusher(RuntimeConfig cfg) async {
  debugPrint('🔧 [Pusher] Initializing...');
  try {
    _reg<PusherService>(() => PusherService());
    final pusher = sl<PusherService>();

    if (pusher.isInitialized &&
        !pusher.isInBadState &&
        cfg.pusherKey.isNotEmpty &&
        cfg.pusherKey != 'disabled') {
      debugPrint('✅ [Pusher] Already initialized');
      if (!pusher.isConnected) await pusher.connect();
      return;
    }

    if (pusher.isInitialized && pusher.isInBadState) {
      debugPrint('⚠️ [Pusher] Bad state — refresh service will fix');
      return;
    }

    if (cfg.pusherKey.isEmpty || cfg.pusherKey == 'disabled') {
      await pusher.initialize(
        apiKey: 'disabled',
        cluster: 'mt1',
        authEndpoint: null,
        authCallback: null,
      );
      debugPrint('⚠️ [Pusher] Initialized in disabled state (no key)');
      return;
    }

    await pusher.initialize(
      apiKey: cfg.pusherKey,
      cluster: cfg.pusherCluster,
      authEndpoint: '${cfg.apiBaseUrl}/broadcasting/auth',
      authCallback: (channelName, socketId, options) async {
        final token = await sl<AuthLocalDataSource>().readToken();
        if (token == null || token.isEmpty) throw Exception('No auth token');
        final res = await sl<Dio>(instanceName: 'mainDio').post(
          '/broadcasting/auth',
          data: {'socket_id': socketId, 'channel_name': channelName},
          options: Options(
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ),
        );
        return res.data;
      },
    );
    debugPrint('✅ [Pusher] Initialized');
  } catch (e) {
    debugPrint('⚠️ [Pusher] Init failed (non-fatal): $e');
  }
}

// =============================================================================
// LIVE VIEWER SERVICES
// =============================================================================
void _initLiveViewerServices() {
  _reg<AgoraViewerService>(
    () => AgoraViewerService(
      onTokenRefresh: (role) async {
        try {
          final channel = sl<AgoraViewerService>().channelId;
          if (channel == null || channel.isEmpty) throw Exception('No channel');
          final token = await sl<AuthLocalDataSource>().readToken();
          final res = await sl<Dio>(instanceName: 'mainDio').post(
            '/api/v1/live/refresh-token',
            data: {'role': role, 'channel': channel},
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          return (res.data as Map<String, dynamic>)['token'] as String;
        } catch (e) {
          debugPrint('❌ Token refresh: $e');
          return '';
        }
      },
    ),
  );
  _reg<LiveStreamService>(
    () => LiveStreamService(
      agoraService: sl<AgoraViewerService>(),
      tokenRefresher: sl<AgoraViewerService>().onTokenRefresh,
    ),
  );
  _reg<NetworkMonitorService>(
    () => NetworkMonitorService(sl<LiveStreamService>()),
  );
  _reg<ReconnectionService>(() => ReconnectionService(sl<LiveStreamService>()));
  _reg<RoleChangeService>(() => RoleChangeService(sl<LiveStreamService>()));

  if (!sl.isRegistered<ViewerBloc>()) {
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
  }
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
// BACKWARDS-COMPAT PUBLIC API
// (called from feature code that still uses the old function names)
// =============================================================================
void wallet() => _initWalletModule();
void setWalletPin() {} // merged into _initWalletModule
void transfercoin() => _initTransferModule();
void withdrawal() => _initWithdrawalModule();

void registerProfileView() => _initProfileViewModule();
void registerChat() => _initChatModule();
void registerPosts() => _initPostsModule();
void creatPost() => _initCreatePostModule();
void liveFeeds() => _initLiveFeedsModule();
void _initializeClubsModule() => _initClubsModule();
void _initializeLiveModule() => _initLiveModule();
void _initializeLiveViewerServices() => _initLiveViewerServices();
