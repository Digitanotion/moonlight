import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/wallet/domain/repositories/pin_repository.dart';

part 'set_new_pin_state.dart';

enum SetNewPinErrorType { generic, validation, pinAlreadySet, network }

class SetNewPinCubit extends Cubit<SetNewPinState> {
  final PinRepository _pinRepository;

  SetNewPinCubit(this._pinRepository) : super(SetNewPinInitial());

  Future<void> setNewPin({
    required String pin,
    required String confirmPin,
  }) async {
    try {
      emit(SetNewPinLoading());

      // Validate PIN format
      if (!_isValidPin(pin)) {
        throw Exception('PIN must be exactly 4 digits');
      }

      if (pin != confirmPin) {
        throw Exception('PIN confirmation does not match');
      }

      final result = await _pinRepository.setPin(
        pin: pin,
        confirmPin: confirmPin,
      );

      if (result['status'] == 'success') {
        emit(
          SetNewPinSuccess(
            result['message'] ?? 'PIN set successfully',
            data: result['data'] ?? {},
          ),
        );
      } else {
        final message = result['message'] ?? 'Failed to set PIN';
        final errorType = _mapErrorType(message);
        emit(SetNewPinError(message, errorType));
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      final errorType = _mapErrorType(errorMessage);
      emit(SetNewPinError(errorMessage, errorType));
    } catch (e) {
      emit(SetNewPinError(e.toString(), SetNewPinErrorType.generic));
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
        return 'Invalid request. Please try again.';
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
        return 'Too many attempts. Please try again later.';
      }

      if (statusCode == 500) {
        return 'Server error. Please try again later.';
      }
    }

    return 'Failed to set PIN. Please try again.';
  }

  SetNewPinErrorType _mapErrorType(String message) {
    if (message.toLowerCase().contains('pin already set')) {
      return SetNewPinErrorType.pinAlreadySet;
    }
    if (message.toLowerCase().contains('validation')) {
      return SetNewPinErrorType.validation;
    }
    if (message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('timeout') ||
        message.toLowerCase().contains('connection')) {
      return SetNewPinErrorType.network;
    }
    return SetNewPinErrorType.generic;
  }
}
