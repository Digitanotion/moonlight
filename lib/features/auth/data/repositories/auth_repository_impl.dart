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
      final userModel = await remoteDataSource.loginWithEmail(
        email,
        password,
        deviceName,
      );

      if (userModel.authToken != null) {
        await localDataSource.cacheToken(userModel.authToken!);
        await localDataSource.cacheUser(userModel);
      }

      return Right(userModel.toEntity());
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
    String? name,
  }) async {
    try {
      final userModel = await remoteDataSource.signUpWithEmail(
        email: email,
        password: password,
        passwordConfirmation: password,
        name: name,
      );

      if (userModel.authToken != null) {
        await localDataSource.cacheToken(userModel.authToken!);
        await localDataSource.cacheUser(userModel);
      }

      return Right(userModel.toEntity());
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
      final userModel = await remoteDataSource.socialLogin(
        provider,
        deviceName,
      );

      await localDataSource.cacheToken(userModel.authToken!);
      await localDataSource.cacheUser(userModel);

      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  @override
  Future<Either<Failure, User>> loginWithGoogle() async {
    try {
      final firebaseToken = await googleSignInService.getFirebaseIdToken();
      final deviceName = await _getDeviceName();

      final userModel = await remoteDataSource.loginWithGoogle(
        firebaseToken,
        deviceName,
      );

      if (userModel.authToken != null) {
        await localDataSource.cacheToken(userModel.authToken!);
        await localDataSource.cacheUser(userModel);
      }

      return Right(userModel.toEntity());
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
}
