// lib/core/injection_container.dart
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/features/edit_profile/presentation/cubit/edit_profile_cubit.dart';
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
import 'package:moonlight/features/user_interest/presentation/cubit/user_interest_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Services
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

// INTERESTS (Profile – interests selection)

final sl = GetIt.instance;

/// Update base URL here if the backend changes environments.
const _baseUrl = 'https://svc.moonlightstream.app/api/';

Future<void> init() async {
  // SharedPreferences first (used by many)
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sharedPreferences),
  );
  // External services
  sl.registerLazySingleton<DeviceInfoPlugin>(() => DeviceInfoPlugin());
  sl.registerLazySingleton<GoogleSignInService>(() => GoogleSignInService());

  // ---------- DIO (single source of truth) ----------
  // sl.registerLazySingleton<Dio>(
  //   () => buildDio(baseUrl: _baseUrl, prefs: sl<SharedPreferences>()),
  // );
  final dioClient = DioClient(
    '${_baseUrl}',
    sl<AuthLocalDataSource>(), // provides readToken()
  );
  sl.registerLazySingleton<Dio>(() => dioClient.dio);

  // ---------- Data sources ----------
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl<Dio>()),
  );
  // sl.registerLazySingleton<AuthLocalDataSource>(
  //   () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  // );

  sl.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<CountryLocalDataSource>(
    () => CountryLocalDataSourceImpl(),
  );

  // SEARCH
  sl.registerLazySingleton<SearchRemoteDataSource>(
    () => SearchRemoteDataSourceImpl(),
  );

  // PROFILE SETUP remote DS:
  // If your ProfileRemoteDataSourceImpl has a Dio parameter:

  // If it does NOT accept Dio, use the no-arg constructor instead and comment the above:
  // sl.registerLazySingleton<ProfileRemoteDataSource>(() => ProfileRemoteDataSourceImpl());

  // ---------- Repositories ----------
  sl.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(localDataSource: sl()),
  );

  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(
      remote: sl(),
      countryLocal: sl(),
      local:
          sl<
            AuthLocalDataSource
          >(), // this is your SharedPreferences-backed impl
    ),
  );

  // Auth repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      deviceInfo: sl(),
      googleSignInService: sl(),
    ),
  );

  // ---------- Use cases ----------
  sl.registerLazySingleton<GetCurrentUser>(() => GetCurrentUser(sl()));
  sl.registerLazySingleton<CheckAuthStatus>(() => CheckAuthStatus(sl()));
  sl.registerLazySingleton<LoginWithEmail>(() => LoginWithEmail(sl()));
  sl.registerLazySingleton<SignUpWithEmail>(() => SignUpWithEmail(sl()));
  sl.registerLazySingleton<SocialLogin>(() => SocialLogin(sl()));
  sl.registerLazySingleton<Logout>(() => Logout(sl()));

  sl.registerLazySingleton<SearchContent>(() => SearchContent(sl()));
  sl.registerLazySingleton<GetTrendingTags>(() => GetTrendingTags(sl()));
  sl.registerLazySingleton<GetSuggestedUsers>(() => GetSuggestedUsers(sl()));
  sl.registerLazySingleton<GetPopularClubs>(() => GetPopularClubs(sl()));
  sl.registerLazySingleton(() => SetupProfile(sl()));
  sl.registerLazySingleton(() => UpdateInterests(sl()));
  sl.registerLazySingleton(() => UpdateProfile(sl()));
  sl.registerLazySingleton(() => FetchMyProfile(sl()));

  // ---------- Blocs ----------
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
  // cubits
  sl.registerFactory(() => ProfileSetupCubit(sl(), sl()));
  sl.registerFactory(() => UserInterestCubit(sl()));
  sl.registerFactory(() => ProfilePageCubit(fetchMyProfile: sl()));
  // Cubit
  sl.registerFactory(
    () => EditProfileCubit(
      fetchMyProfile: sl(), // /v1/me
      updateProfile: sl(), // PUT /v1/profile/update
      profileRepo: sl(), // countries
      authLocal: sl(),
      getCurrentUser: sl(), // cache updated profile if needed
    ),
  );
}

/// Centralized Dio builder with sane defaults + auth header.
/// Reads the token from SharedPreferences and injects it as:
///   Authorization: Bearer <token>
Dio buildDio({required String baseUrl, required SharedPreferences prefs}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
      // Important to let Dio pick correct content-type for multipart, JSON, etc.
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Read token from prefs. Adjust keys if your AuthLocalDataSource uses a different one.
        final token =
            prefs.getString('access_token') ??
            prefs.getString('token'); // fallback
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        // Optional: normalize typical API errors
        // You can also add retry/backoff for GETs here if needed.
        // print(e);
        // print("Bearer ${prefs.getString('access_token')}");
        // print("Token: ${prefs.getString('token')}");
        return handler.next(e);
      },
    ),
  );

  return dio;
}
