import 'package:dio/dio.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/settings/data/datasources/change_username_remote_datasource.dart';
import 'package:moonlight/features/settings/domain/entities/notification_settings.dart';
import 'package:moonlight/features/settings/domain/repositories/change_username_repository.dart';

class ChangeUsernameRepositoryImpl implements ChangeUsernameRepository {
  final ChangeUsernameRemoteDataSource _remoteDataSource;

  ChangeUsernameRepositoryImpl(this._remoteDataSource);

  @override
  Future<Map<String, dynamic>> changeUsername({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _remoteDataSource.changeUsername(
        username: username,
        password: password,
      );

      final data = response;

      // Validate response structure
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response format');
      }

      return data;
    } on DioException catch (e) {
      final errorData = e.response?.data;

      if (errorData is Map) {
        final message = errorData['message']?.toString();
        final errors = errorData['errors'];

        if (errors is Map && errors['password'] != null) {
          throw Exception('Incorrect password');
        }

        if (message?.toLowerCase().contains('taken') == true ||
            message?.toLowerCase().contains('already') == true) {
          throw Exception('Username is already taken');
        }

        if (message?.toLowerCase().contains('cooldown') == true ||
            message?.toLowerCase().contains('30 days') == true) {
          throw Exception(
            'You can only change your username once every 30 days',
          );
        }

        throw Exception(message ?? 'Failed to change username');
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('Connection timeout. Please try again.');
      }

      if (e.type == DioExceptionType.connectionError) {
        throw Exception('No internet connection');
      }

      throw Exception('Failed to change username: ${e.message}');
    } catch (e) {
      if (e is! Exception) {
        return Future.error(Exception('Unexpected error: $e'));
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> checkUsername(String username) async {
    try {
      final response = await _remoteDataSource.checkUsername(username);

      final data = response;

      // Validate response structure
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response format');
      }

      return data;
    } on DioException catch (e) {
      final errorData = e.response?.data;

      if (errorData is Map<String, dynamic>) {
        final message = errorData['message']?.toString();

        // For check username, we want to return the error in the response
        // so the UI can show suggestions
        if (errorData.containsKey('available') ||
            errorData.containsKey('suggestions') ||
            errorData.containsKey('validation_errors')) {
          return errorData;
        }

        throw Exception(message ?? 'Failed to check username');
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('Connection timeout');
      }

      throw Exception('Network error');
    } catch (e) {
      if (e is! Exception) {
        return Future.error(Exception('Unexpected error: $e'));
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getUsernameHistory({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await _remoteDataSource.getUsernameHistory(
        page: page,
        perPage: perPage,
      );

      final data = response;

      // Validate response structure
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response format');
      }

      return data;
    } on DioException catch (e) {
      final errorData = e.response?.data;

      if (errorData is Map) {
        final message = errorData['message']?.toString();
        throw Exception(message ?? 'Failed to get username history');
      }

      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout');
      }

      throw Exception('Network error');
    } catch (e) {
      if (e is! Exception) {
        return Future.error(Exception('Unexpected error: $e'));
      }
      rethrow;
    }
  }
}
