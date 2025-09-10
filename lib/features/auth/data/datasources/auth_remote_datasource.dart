import 'package:dio/dio.dart';
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

  Future<LoginResponseModel> loginWithGoogle(
    String firebaseToken,
    String deviceName,
  );

  Future<UserModel> loginWithFirebase(String firebaseToken, String deviceName);

  Future<String> forgotPassword(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio client;

  AuthRemoteDataSourceImpl({required this.client});
  @override
  Future<UserModel> fetchMe() async {
    final res = await client.get(
      '/v1/me',
    ); // Sanctum token already on interceptor
    // API shape: { "data": { ...UserResource } }
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
        'https://svc.moonlightstream.app/api/v1/login',
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
        'https://svc.moonlightstream.app/api/v1/register',
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
    String firebaseToken,
    String deviceName,
  ) async {
    try {
      final response = await client.post(
        'https://svc.moonlightstream.app/api/v1/login/firebase',
        data: {'firebase_token': firebaseToken, 'device_name': deviceName},
      );

      final data = response.data;
      return LoginResponseModel.fromJson({
        'access_token': data['token'],
        'user': data['user'],
      });
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['error'] ?? 'Google login failed',
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

      final data = response.data;
      return UserModel.fromJson({
        ...data['user'],
        'access_token': data['token'],
      });
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['error'] ?? 'Firebase login failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<String> forgotPassword(String email) async {
    try {
      final response = await client.post(
        "https://svc.moonlightstream.app/api/v1/forgot-password",
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
}
