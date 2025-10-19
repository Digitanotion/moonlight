import 'package:dartz/dartz.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/core/services/google_signin_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:moonlight/features/auth/data/models/user_model.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';
import 'package:moonlight/features/auth/domain/repositories/auth_repository.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart'
    hide AuthFailure;
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource localDataSource;
  final AuthRemoteDataSource remoteDataSource;
  final DeviceInfoPlugin deviceInfo;
  final GoogleSignInService googleSignInService;

  AuthRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.deviceInfo,
    required this.googleSignInService,
  });

  Future<String> _getDeviceName() async {
    final deviceInfoData = await deviceInfo.deviceInfo;
    return deviceInfoData.data['model'] ?? 'Unknown Device';
  }

  @override
  Future<Either<Failure, bool>> isLoggedIn() async {
    try {
      final token = await localDataSource.getAuthToken();
      return Right(token != null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      final userModel = await localDataSource.getCurrentUser();
      return Right(userModel.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await localDataSource.clearToken();
      await localDataSource.clearUserData();
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> getAuthToken() async {
    try {
      final token = await localDataSource.getAuthToken();
      return token != null
          ? Right(token)
          : const Left(CacheFailure('No token found'));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, User>> loginWithEmail(
    String email,
    String password,
  ) async {
    try {
      final deviceName = await _getDeviceName();

      // 1) Login -> get tokens
      final loginResponse = await remoteDataSource.loginWithEmail(
        email,
        password,
        deviceName,
      );

      // Cache the token first
      if (loginResponse.accessToken != null) {
        await localDataSource.cacheToken(loginResponse.accessToken!);
      }

      // 2) Fetch full profile from /v1/me endpoint (has complete user data including avatar)
      final fullUserProfile = await remoteDataSource.fetchMe();

      // 3) Merge token fields into the full profile
      final mergedUser = fullUserProfile.copyWith(
        authToken: loginResponse.accessToken,
        tokenType: loginResponse.tokenType,
        expiresIn: loginResponse.expiresIn,
      );

      // 4) Cache the complete user data
      await localDataSource.cacheUser(mergedUser);

      return Right(mergedUser.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, User>> signUpWithEmail({
    required String email,
    required String password,
    String? agent_name,
  }) async {
    try {
      // 1) Register -> may return token depending on backend
      final signUpResponse = await remoteDataSource.signUpWithEmail(
        email: email,
        password: password,
        passwordConfirmation: password,
        agent_name: agent_name,
      );

      // 2) Fetch full profile
      final me = await remoteDataSource.fetchMe();

      // 3) Merge token fields if present
      final merged = me.copyWith(
        authToken: signUpResponse.accessToken,
        tokenType: signUpResponse.tokenType,
        expiresIn: signUpResponse.expiresIn,
      );

      if (merged.authToken != null) {
        await localDataSource.cacheToken(merged.authToken!);
        await localDataSource.cacheUser(merged);
      }

      return Right(merged.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, User>> socialLogin(String provider) async {
    try {
      final deviceName = await _getDeviceName();

      final loginResponse = await remoteDataSource.socialLogin(
        provider,
        deviceName,
      );

      final me = await remoteDataSource.fetchMe();

      final merged = me.copyWith(
        authToken: loginResponse.accessToken,
        tokenType: loginResponse.tokenType,
        expiresIn: loginResponse.expiresIn,
      );

      if (merged.authToken != null) {
        await localDataSource.cacheToken(merged.authToken!);
        await localDataSource.cacheUser(merged);
      }

      return Right(merged.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, User>> loginWithGoogle() async {
    try {
      final firebaseToken = await googleSignInService.getFirebaseIdToken();
      final deviceName = await _getDeviceName();

      final loginResponse = await remoteDataSource.loginWithGoogle(
        firebaseToken,
        deviceName,
      );

      final me = await remoteDataSource.fetchMe();

      final merged = me.copyWith(
        authToken: loginResponse.accessToken,
        tokenType: loginResponse.tokenType,
        expiresIn: loginResponse.expiresIn,
      );

      if (merged.authToken != null) {
        await localDataSource.cacheToken(merged.authToken!);
        await localDataSource.cacheUser(merged);
      }

      return Right(merged.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(
        AuthFailure('Unknown error during Google sign-in: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, String>> forgotPassword(String email) async {
    try {
      final message = await remoteDataSource.forgotPassword(email);
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
