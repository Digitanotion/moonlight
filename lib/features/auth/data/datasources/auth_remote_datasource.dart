import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponseModel> loginWithEmail(
    String email,
    String password,
    String deviceName,
  );
  Future<UserModel> fetchMe();

  Future<LoginResponseModel> signUpWithEmail({
    required String email,
    required String password,
    required String passwordConfirmation,
    String? agent_name,
    String? referralCode,
  });

  Future<LoginResponseModel> socialLogin(String provider, String deviceName);

  // UPDATE: Changed parameter name from firebaseToken to idToken
  Future<LoginResponseModel> loginWithGoogle(
    String idToken, // Changed from firebaseToken
    String deviceName,
  );

  // KEEP: For Firebase-based Google login (alternative)
  Future<UserModel> loginWithFirebase(String firebaseToken, String deviceName);

  // NEW: Google OAuth login using ID token
  Future<LoginResponseModel> googleOAuthLogin(
    String idToken,
    String deviceName,
  );

  Future<String> forgotPassword(String email);

  /// Refresh the current auth token using server refresh endpoint.
  /// On success this implementation persists the new token(s) into SharedPreferences
  /// using keys 'access_token' and 'token'.
  Future<void> refreshToken();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio client;
  final SharedPreferences prefs;

  AuthRemoteDataSourceImpl({required this.client, required this.prefs});

  final BaseUrl = "https://svc.moonlightstream.app/api";

  @override
  /*************  ✨ Windsurf Command ⭐  *************/
  /// Fetch the current user's profile information.
  ///
  /// This endpoint is accessible only with a valid access token.
  ///
  /// Returns a [UserModel] containing the user's information.
  ///
  /*******  0766317b-8522-4e05-aecc-3c176077396c  *******/
  Future<UserModel> fetchMe() async {
    final res = await client.get(
      '${BaseUrl}/v1/profile/me',
    ); // Sanctum token already on interceptor
    final data = (res.data is Map && res.data['data'] is Map)
        ? Map<String, dynamic>.from(res.data['data'] as Map)
        : <String, dynamic>{};
    return UserModel.fromUserResource(data);
  }

  @override
  Future<LoginResponseModel> loginWithEmail(
    String email,
    String password,
    String deviceName,
  ) async {
    try {
      final response = await client.post(
        '${BaseUrl}/v1/login',
        data: {'email': email, 'password': password, 'device_name': deviceName},
      );

      final data = response.data;
      return LoginResponseModel.fromJson({
        'access_token': data['access_token'],
        'token_type': data['token_type'],
        'expiresIn': data['expires_in'] != "0" ? data['expires_in'] : 0,
        'user': data['user'],
      });
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['message'] ?? 'Login failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<LoginResponseModel> signUpWithEmail({
    required String email,
    required String password,
    required String passwordConfirmation,
    String? agent_name,
    String? referralCode,
  }) async {
    try {
      final response = await client.post(
        '${BaseUrl}/v1/register',
        data: {
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          if (agent_name != null && agent_name.isNotEmpty)
            'agent_name': agent_name,
          if (referralCode != null && referralCode.isNotEmpty)
            'referral_code': referralCode,
        },
      );

      final data = response.data;
      return LoginResponseModel.fromJson({
        'access_token': data['access_token'],
        'token_type': data['token_type'],
        'expires_in': data['expires_in'],
        'user': data['user'],
      });
    } on DioException catch (e) {
      final errors = e.response?.data['errors'];
      final errorMessage =
          _parseValidationErrors(errors) ??
          e.response?.data['message'] ??
          'Registration failed';
      throw ServerException(errorMessage, statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<LoginResponseModel> socialLogin(
    String provider,
    String deviceName,
  ) async {
    try {
      final response = await client.post(
        '/v1/login/$provider',
        data: {'device_name': deviceName},
      );

      final data = response.data;
      return LoginResponseModel.fromJson({
        'access_token': data['access_token'],
        'user': data['user'],
      });
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['message'] ?? '$provider login failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<LoginResponseModel> loginWithGoogle(
    String idToken,
    String deviceName,
  ) async {
    try {
      final response = await client.post(
        '${BaseUrl}/v1/auth/google/login',
        data: {'id_token': idToken, 'device_name': deviceName},
      );

      final data = response.data;
      return LoginResponseModel.fromJson({
        'access_token': data['access_token'],
        'token_type': data['token_type'],
        'expires_in': data['expires_in'],
        'user': data['user'],
      });
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['message'] ?? 'Google login failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // Update the Firebase method too
  @override
  Future<UserModel> loginWithFirebase(
    String firebaseToken,
    String deviceName,
  ) async {
    try {
      final response = await client.post(
        '${BaseUrl}/v1/auth/google/firebase',
        data: {'firebase_token': firebaseToken, 'device_name': deviceName},
      );

      final data = response.data as Map<String, dynamic>;

      // ✅ DEBUG: Check types
      debugPrint("🟡 expires_in type: ${data['expires_in'].runtimeType}");
      debugPrint("🟡 expires_in value: ${data['expires_in']}");

      // Handle int/string conversion
      final expiresIn = data['expires_in'];
      final expiresInInt = expiresIn is int
          ? expiresIn
          : expiresIn is String
          ? int.tryParse(expiresIn)
          : null;

      // Create UserModel with proper types
      return UserModel(
        uuid: data['user']?['uuid'] as String?,
        userId: data['user']?['id']?.toString(), // Convert to String if needed
        email: data['user']?['email'] as String? ?? '',
        // ... other user fields ...
        authToken: data['access_token'] as String?,
        tokenType: data['token_type'] as String?,
        expiresIn: expiresInInt.toString(), // Use the converted int
      );
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['message'] ?? 'Firebase login failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // NEW: Alias method for consistency
  @override
  Future<LoginResponseModel> googleOAuthLogin(
    String idToken,
    String deviceName,
  ) async {
    return loginWithGoogle(idToken, deviceName);
  }

  // KEEP: For Firebase-based login (alternative)
  // @override
  // Future<UserModel> loginWithFirebase(
  //   String firebaseToken,
  //   String deviceName,
  // ) async {
  //   try {
  //     final response = await client.post(
  //       '${BaseUrl}/v1/login/firebase',
  //       data: {'firebase_token': firebaseToken, 'device_name': deviceName},
  //     );

  //     final data = response.data;
  //     return UserModel.fromJson({
  //       ...data['user'],
  //       'access_token': data['token'],
  //     });
  //   } on DioException catch (e) {
  //     throw ServerException(
  //       e.response?.data['error'] ?? 'Firebase login failed',
  //       statusCode: e.response?.statusCode,
  //     );
  //   }
  // }

  @override
  Future<String> forgotPassword(String email) async {
    try {
      final response = await client.post(
        "${BaseUrl}/v1/forgot-password",
        data: {'email': email},
      );

      if (response.statusCode == 200) {
        return response.data['message'];
      } else if (response.statusCode == 422) {
        throw ServerException(
          response.data['errors']['email'][0],
          statusCode: 422,
        );
      } else {
        throw ServerException(
          response.data['message'] ?? 'Unknown error',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['message'] ?? 'Forgot password failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  String? _parseValidationErrors(Map<String, dynamic>? errors) {
    if (errors == null) return null;

    final errorMessages = <String>[];
    errors.forEach((key, value) {
      if (value is List) {
        errorMessages.addAll(value.map((e) => e.toString()));
      } else {
        errorMessages.add(value.toString());
      }
    });

    return errorMessages.join(', ');
  }

  /// Refresh token implementation:
  ///
  /// - Calls `${BaseUrl}/v1/refresh` using current Authorization header (set by interceptors).
  /// - On success expects server to return a JSON payload containing either:
  ///     - { "access_token": "<token>", ... } OR
  ///     - { "token": "<token>", ... }
  /// - Persists token to SharedPreferences under keys 'access_token' and 'token' so other parts
  ///   of the app (and existing code) can read it.
  /// - Throws ServerException on failure.
  @override
  Future<void> refreshToken() async {
    try {
      final response = await client.post('${BaseUrl}/v1/refresh');
      final data = response.data as Map<String, dynamic>? ?? {};
      final token = (data['access_token'] ?? data['token'])?.toString();

      if (token == null || token.isEmpty) {
        throw ServerException(
          'Refresh token failed: no token returned',
          statusCode: response.statusCode,
        );
      }

      // Persist to SharedPreferences using both common keys used by the app
      await prefs.setString('access_token', token);
      await prefs.setString('token', token);
    } on DioException catch (e) {
      // surface a friendly server exception with details if available
      final message = e.response?.data is Map
          ? (e.response!.data['message'] ?? 'Token refresh failed')
          : 'Token refresh failed';
      throw ServerException(message, statusCode: e.response?.statusCode);
    } catch (e) {
      throw ServerException('Token refresh failed: $e');
    }
  }
}
