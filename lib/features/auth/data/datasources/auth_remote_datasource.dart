import 'package:dio/dio.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> loginWithEmail(
    String email,
    String password,
    String deviceName,
  );

  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String passwordConfirmation,
    String? name,
    String? referralCode,
  });
  Future<UserModel> socialLogin(String provider, String deviceName);
  Future<UserModel> loginWithGoogle(String firebaseToken, String deviceName);
  Future<UserModel> loginWithFirebase(String firebaseToken, String deviceName);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio client;

  AuthRemoteDataSourceImpl({required this.client});

  @override
  Future<UserModel> loginWithEmail(
    String email,
    String password,
    String deviceName,
  ) async {
    try {
      final response = await client.post(
        'https://svc.moonlightstream.app/api/v1/login',
        data: {'email': email, 'password': password, 'device_name': deviceName},
      );

      // Handle API response structure
      final responseData = response.data;
      return UserModel.fromJson({
        ...responseData['user'],
        'access_token': responseData['access_token'],
        'token_type': responseData['token_type'],
        'expires_in': responseData['expires_in'],
      });
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['message'] ?? 'Login failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String passwordConfirmation,
    String? name,
    String? referralCode,
  }) async {
    try {
      final response = await client.post(
        'https://svc.moonlightstream.app/api/v1/register',
        data: {
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          if (name != null && name.isNotEmpty) 'name': name,
          if (referralCode != null && referralCode.isNotEmpty)
            'referral_code': referralCode,
        },
      );

      // Handle registration response structure
      final responseData = response.data;
      print(responseData);
      return UserModel.fromJson(responseData['user']);
    } on DioException catch (e) {
      print('❌ Registration error raw: ${e.response?.data}');
      final errors = e.response?.data['errors'];
      final errorMessage =
          _parseValidationErrors(errors) ??
          e.response?.data['message'] ??
          'Registration failed ${e.message}';

      throw ServerException(errorMessage, statusCode: e.response?.statusCode);
    }
  }

  @override
  Future<UserModel> socialLogin(String provider, String deviceName) async {
    try {
      final response = await client.post(
        '/v1/login/$provider',
        data: {'device_name': deviceName},
      );

      final responseData = response.data;
      return UserModel.fromJson({
        ...responseData['user'],
        'access_token': responseData['access_token'],
      });
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['message'] ?? '$provider login failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<UserModel> loginWithFirebase(
    String firebaseToken,
    String deviceName,
  ) async {
    try {
      final response = await client.post(
        'https://svc.moonlightstream.app/api/v1/login/firebase',
        data: {'firebase_token': firebaseToken, 'device_name': deviceName},
      );

      final responseData = response.data;
      return UserModel.fromJson({
        ...responseData['user'],
        'access_token': responseData['token'],
      });
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['error'] ?? 'Firebase login failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<UserModel> loginWithGoogle(
    String firebaseToken,
    String deviceName,
  ) async {
    try {
      final response = await client.post(
        'https://svc.moonlightstream.app/api/v1/login/firebase',
        data: {'firebase_token': firebaseToken, 'device_name': deviceName},
      );

      final responseData = response.data;
      return UserModel.fromJson({
        ...responseData['user'],
        'access_token': responseData['token'],
      });
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['error'] ?? 'Google login failed',
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
}
