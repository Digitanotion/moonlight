import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/services/google_signin_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:moonlight/features/profile/data/datasources/interests_local_data_source.dart';
import 'package:moonlight/features/profile_setup/data/datasources/profile_remote_data_source.dart';
import 'package:moonlight/features/profile_setup/data/repositories/profile_repository_impl.dart';
import 'package:moonlight/features/profile_setup/domain/repositories/profile_repository.dart';
import 'package:moonlight/features/profile_setup/domain/usecases/get_countries.dart';
import 'package:moonlight/features/profile_setup/domain/usecases/update_profile.dart';
import 'package:moonlight/features/profile_setup/presentation/bloc/profile_setup_bloc.dart';
import 'package:moonlight/features/search/data/datasources/search_remote_data_source.dart';
import 'package:moonlight/features/search/data/repositories/search_repository_impl.dart';
import 'package:moonlight/features/search/domain/repositories/search_repository.dart';
import 'package:moonlight/features/search/domain/usecases/get_popular_clubs.dart';
import 'package:moonlight/features/search/domain/usecases/get_suggested_users.dart';
import 'package:moonlight/features/search/domain/usecases/get_trending_tags.dart';
import 'package:moonlight/features/search/domain/usecases/search_content.dart';
import 'package:moonlight/features/search/presentation/bloc/search_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

import 'package:moonlight/features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'package:moonlight/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:moonlight/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';

import 'package:moonlight/features/profile/domain/repositories/interest_repository.dart';
import 'package:moonlight/features/profile/domain/usecases/get_interests.dart';
import 'package:moonlight/features/profile/domain/usecases/save_user_interests.dart';
import 'package:moonlight/features/profile/presentation/bloc/interest_bloc.dart';
import 'package:moonlight/features/profile/domain/usecases/has_completed_selection.dart';

import 'package:moonlight/features/profile/data/datasources/interests_local_data_source.dart';
import 'package:moonlight/features/profile/data/datasources/interests_remote_data_source.dart';
import 'package:moonlight/features/profile/data/repositories/interest_repository_impl.dart';
import 'package:moonlight/features/profile/data/repositories/interest_repository_mock_impl.dart';

final sl = GetIt.instance;

Future<void> init() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // external
  sl.registerLazySingleton<Dio>(() => Dio());
  // Add device info
  sl.registerLazySingleton(() => DeviceInfoPlugin());
  sl.registerLazySingleton(() => GoogleSignInService());

  // 🔹 Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl()),
  );

  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl()),
  );

  sl.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<InterestsLocalDataSource>(
    () => InterestsLocalDataSourceImpl(sl<SharedPreferences>()),
  );

  // 🔹 Repositories

  sl.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<SearchRemoteDataSource>(
    () => SearchRemoteDataSourceImpl(),
  );

  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<InterestRepository>(
    () => InterestRepositoryMockImpl(local: sl<InterestsLocalDataSource>()),
  );

  // Update repository with device info
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      deviceInfo: sl(),
      googleSignInService: sl(),
    ),
  );

  // 🔹 Use cases
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => CheckAuthStatus(sl()));
  sl.registerLazySingleton(() => LoginWithEmail(sl()));
  sl.registerLazySingleton(() => SignUpWithEmail(sl()));
  sl.registerLazySingleton(() => SocialLogin(sl()));
  sl.registerLazySingleton(() => Logout(sl()));
  sl.registerLazySingleton(() => SearchContent(sl()));
  sl.registerLazySingleton(() => GetTrendingTags(sl()));
  sl.registerLazySingleton(() => GetSuggestedUsers(sl()));
  sl.registerLazySingleton(() => GetPopularClubs(sl()));
  sl.registerLazySingleton<GetInterests>(
    () => GetInterests(sl<InterestRepository>()),
  );
  sl.registerLazySingleton<SaveUserInterests>(
    () => SaveUserInterests(sl<InterestRepository>()),
  );
  sl.registerLazySingleton<HasCompletedSelection>(
    () => HasCompletedSelection(sl<InterestRepository>()),
  );
  // Data Sources
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(),
  );

  // Repositories
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(remoteDataSource: sl()),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetCountries(sl()));
  sl.registerLazySingleton(() => UpdateProfile(sl()));
  // 🔹 Blocs
  sl.registerFactory(() => OnboardingBloc(repository: sl()));
  sl.registerFactory(
    () => ProfileSetupBloc(getCountries: sl(), updateProfile: sl()),
  );
  sl.registerFactory(
    () => SearchBloc(
      searchContent: sl(),
      getTrendingTags: sl(),
      getSuggestedUsers: sl(),
      getPopularClubs: sl(),
    ),
  );
  sl.registerFactory(
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
  sl.registerFactory(
    () => InterestBloc(
      getInterests: sl(),
      saveUserInterests: sl(),
      hasCompletedSelection: sl(),
    ),
  );
}
