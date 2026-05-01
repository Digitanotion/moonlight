import 'package:dartz/dartz.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/core/services/firebase_google_signin_service.dart';
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

      final googleService = FirebaseGoogleSignInService();
      await googleService.signOut();

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

      final loginResponse = await remoteDataSource.loginWithEmail(
        email,
        password,
        deviceName,
      );

      if (loginResponse.accessToken != null) {
        await localDataSource.cacheToken(loginResponse.accessToken!);
      }

      final fullUserProfile = await remoteDataSource.fetchMe();

      final mergedUser = fullUserProfile.copyWith(
        authToken: loginResponse.accessToken,
        tokenType: loginResponse.tokenType,
        expiresIn: loginResponse.expiresIn,
      );

      await localDataSource.cacheUser(mergedUser);

      return Right(mergedUser.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Login failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, User>> signUpWithEmail({
    required String email,
    required String password,
    String? agent_name,
  }) async {
    try {
      final signUpResponse = await remoteDataSource.signUpWithEmail(
        email: email,
        password: password,
        passwordConfirmation: password,
        agent_name: agent_name,
      );

      // ✅ Don't call fetchMe() here — the user hasn't verified their
      // email yet, so /profile/me will return 401/403 and crash the flow.
      // Build the user from the signup response directly instead.
      final userModel =
          signUpResponse.user?.copyWith(
            authToken: signUpResponse.accessToken,
            tokenType: signUpResponse.tokenType,
            expiresIn: signUpResponse.expiresIn,
          ) ??
          UserModel(
            email: email,
            agent_name: agent_name,
            authToken: signUpResponse.accessToken,
            tokenType: signUpResponse.tokenType,
            expiresIn: signUpResponse.expiresIn,
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
    } catch (e) {
      // ✅ Catch anything unexpected so the bloc never gets stuck in AuthLoading
      return Left(ServerFailure('Registration failed: ${e.toString()}'));
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
    } catch (e) {
      return Left(ServerFailure('Social login failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, User>> loginWithGoogle() async {
    try {
      debugPrint("🟡 Using Firebase Google Sign-In...");

      final firebaseGoogleService = FirebaseGoogleSignInService();
      final firebaseData = await firebaseGoogleService.signIn();
      final firebaseToken = firebaseData['firebaseToken'] as String;

      if (firebaseToken.isEmpty) {
        return Left(AuthFailure('Failed to get Firebase token'));
      }

      final deviceName = await _getDeviceName();

      debugPrint(
        "🟡 Sending Firebase token to backend: ${firebaseToken.substring(0, 50)}...",
      );

      final userModel = await remoteDataSource.loginWithFirebase(
        firebaseToken,
        deviceName,
      );

      debugPrint("✅ Backend response received!");
      debugPrint(
        "   Access token: ${userModel.authToken?.substring(0, 50)}...",
      );
      debugPrint("   Token type: ${userModel.tokenType}");
      debugPrint("   Expires in: ${userModel.expiresIn}");

      if (userModel.authToken != null) {
        debugPrint("🟡 Caching token...");
        await localDataSource.cacheToken(userModel.authToken!);
        debugPrint("✅ Token cached!");
      }

      debugPrint("🟡 Fetching user profile...");
      final me = await remoteDataSource.fetchMe();
      debugPrint("✅ Profile fetched successfully!");

      final merged = me.copyWith(
        authToken: userModel.authToken,
        tokenType: userModel.tokenType,
        expiresIn: userModel.expiresIn,
      );

      if (merged.authToken != null) {
        await localDataSource.cacheUser(merged);
        debugPrint("✅ User data cached!");
      }

      debugPrint("✅ Firebase Google Sign-In COMPLETE!");
      return Right(merged.toEntity());
    } on ServerException catch (e) {
      debugPrint("🔴 Firebase Google Sign-In server error: ${e.message}");
      debugPrint("🔴 Status code: ${e.statusCode}");
      return Left(ServerFailure(e.message));
    } on DioException catch (e) {
      debugPrint("🔴 Dio error during Google Sign-In:");
      debugPrint("   Status: ${e.response?.statusCode}");
      debugPrint("   Message: ${e.response?.data}");
      debugPrint("   Headers: ${e.response?.headers}");
      return Left(ServerFailure(e.message ?? ""));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e, stackTrace) {
      debugPrint("🔴 Firebase Google Sign-In error: $e");
      debugPrint("Stack: $stackTrace");
      return Left(AuthFailure('Google sign-in failed: ${e.toString()}'));
    }
  }

  Future<Either<Failure, User>> loginWithGoogleToken(String idToken) async {
    try {
      final deviceName = await _getDeviceName();

      final loginResponse = await remoteDataSource.loginWithGoogle(
        idToken,
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
    } catch (e) {
      return Left(AuthFailure('Google login failed: ${e.toString()}'));
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
