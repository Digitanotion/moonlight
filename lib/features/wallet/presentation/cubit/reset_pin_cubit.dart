import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/wallet/domain/repositories/pin_repository.dart';

part 'reset_pin_state.dart';

enum ResetPinErrorType {
  generic,
  invalidCurrentPin,
  validation,
  cooldown,
  network,
}

class ResetPinCubit extends Cubit<ResetPinState> {
  final PinRepository _pinRepository;

  ResetPinCubit(this._pinRepository) : super(ResetPinInitial());

  Future<void> verifyCurrentPin(String currentPin) async {
    try {
      emit(ResetPinLoading());

      if (!_isValidPin(currentPin)) {
        throw Exception('Current PIN must be exactly 4 digits');
      }

      // For now, we'll verify through the reset endpoint
      // If backend has a dedicated verify endpoint, use that instead
      final result = await _pinRepository.verifyPin(currentPin);

      if (result['status'] == 'success') {
        emit(ResetPinCurrentVerified());
      } else {
        final message = result['message'] ?? 'Invalid current PIN';
        emit(ResetPinCurrentError(message));
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      emit(ResetPinCurrentError(errorMessage));
    } catch (e) {
      emit(ResetPinCurrentError('Failed to verify PIN: ${e.toString()}'));
    }
  }

  Future<void> resetPin({
    required String currentPin,
    required String newPin,
    required String confirmNewPin,
  }) async {
    try {
      emit(ResetPinLoading());

      // Validate PINs
      if (!_isValidPin(currentPin)) {
        throw Exception('Current PIN must be exactly 4 digits');
      }

      if (!_isValidPin(newPin)) {
        throw Exception('New PIN must be exactly 4 digits');
      }

      if (newPin != confirmNewPin) {
        throw Exception('New PIN confirmation does not match');
      }

      if (currentPin == newPin) {
        throw Exception('New PIN must be different from current PIN');
      }

      // Validate that pins are not empty
      if (currentPin.isEmpty) {
        throw Exception('Current PIN is required');
      }

      if (newPin.isEmpty) {
        throw Exception('New PIN is required');
      }

      if (confirmNewPin.isEmpty) {
        throw Exception('Confirm new PIN is required');
      }

      final result = await _pinRepository.resetPin(
        currentPin: currentPin,
        newPin: newPin,
        confirmNewPin: confirmNewPin,
      );

      if (result['status'] == 'success') {
        emit(
          ResetPinSuccess(
            result['message'] ?? 'PIN reset successfully',
            data: result['data'] ?? {},
          ),
        );
      } else {
        final message = result['message'] ?? 'Failed to reset PIN';
        final errorType = _mapErrorType(message);
        emit(ResetPinError(message, errorType));
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      final errorType = _mapErrorType(errorMessage);
      emit(ResetPinError(errorMessage, errorType));
    } catch (e) {
      emit(ResetPinError(e.toString(), ResetPinErrorType.generic));
    }
  }

  bool _isValidPin(String pin) {
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  String _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Network timeout. Please check your connection.';
    }

    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please check your network.';
    }

    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;

      if (statusCode == 400) {
        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        }
        return 'Invalid current PIN or PIN not set.';
      }

      if (statusCode == 422) {
        if (data is Map && data['errors'] != null) {
          final errors = data['errors'] as Map<String, dynamic>;
          // Extract first error message
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            return firstError.first.toString();
          }
        }
        return 'PIN validation failed. Please check your input.';
      }

      if (statusCode == 429) {
        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        }
        return 'Too many attempts. Please try again later.';
      }

      if (statusCode == 500) {
        return 'Server error. Please try again later.';
      }
    }

    return 'Failed to reset PIN. Please try again.';
  }

  ResetPinErrorType _mapErrorType(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('invalid current') ||
        lowerMessage.contains('pin not set')) {
      return ResetPinErrorType.invalidCurrentPin;
    }

    if (lowerMessage.contains('validation')) {
      return ResetPinErrorType.validation;
    }

    if (lowerMessage.contains('too many') ||
        lowerMessage.contains('cooldown') ||
        lowerMessage.contains('try again later')) {
      return ResetPinErrorType.cooldown;
    }

    if (lowerMessage.contains('network') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('connection')) {
      return ResetPinErrorType.network;
    }

    return ResetPinErrorType.generic;
  }
}
