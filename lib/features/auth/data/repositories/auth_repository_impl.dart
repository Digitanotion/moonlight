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
      // 1. Logout from your backend
      await localDataSource.clearToken();
      await localDataSource.clearUserData();

      // 2. Logout from Google (important!)
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
      debugPrint("🟡 Using Firebase Google Sign-In...");

      // Use Firebase Google Sign-In service
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

      // Call backend with Firebase token using the loginWithFirebase method
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

      // ✅ CRITICAL: Cache the token FIRST
      if (userModel.authToken != null) {
        debugPrint("🟡 Caching token...");
        await localDataSource.cacheToken(userModel.authToken!);
        debugPrint("✅ Token cached!");
      }

      // Now try to fetch full profile
      debugPrint("🟡 Fetching user profile...");
      final me = await remoteDataSource.fetchMe();
      debugPrint("✅ Profile fetched successfully!");

      // Merge with token information
      final merged = me.copyWith(
        authToken: userModel.authToken,
        tokenType: userModel.tokenType,
        expiresIn: userModel.expiresIn,
      );

      // Cache the complete user
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

  // Alternative method for direct ID token login (if needed)
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
