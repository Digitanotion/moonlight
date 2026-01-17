import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/features/settings/domain/repositories/change_email_repository.dart';

part 'change_email_state.dart';

class ChangeEmailCubit extends Cubit<ChangeEmailState> {
  final ChangeEmailRepository _repository;

  // For analytics/logging
  static const String _tag = 'ChangeEmailCubit';

  ChangeEmailCubit(this._repository) : super(const ChangeEmailState());

  Future<void> requestEmailChange({
    required String newEmail,
    required String confirmNewEmail,
    required String password,
  }) async {
    try {
      // 1. Log attempt for monitoring
      _logEvent('email_change_requested', {'new_email': _maskEmail(newEmail)});

      // 2. Validate inputs before API call
      final validationError = _validateRequestInputs(
        newEmail: newEmail,
        confirmNewEmail: confirmNewEmail,
        password: password,
      );

      if (validationError != null) {
        _logEvent('email_change_validation_failed', {'error': validationError});
        emit(
          ChangeEmailState(
            status: ChangeEmailStatus.error,
            error: validationError,
          ),
        );
        return;
      }

      // 3. Clear any previous errors and set loading
      emit(
        state.copyWith(
          status: ChangeEmailStatus.loading,
          error: null,
          message: null,
        ),
      );

      // 4. Call repository
      final result = await _repository.requestEmailChange(
        currentEmail: '', // Not needed in API
        newEmail: newEmail.trim(),
        confirmNewEmail: confirmNewEmail.trim(),
        password: password,
      );

      // 5. Handle success
      result.fold(
        (failure) {
          emit(
            ChangeEmailState(
              status: ChangeEmailStatus.error,
              error: failure.message,
            ),
          );
        },
        (data) {
          _logEvent('email_change_request_success', {
            'request_id': data['data']['request_id'],
          });

          emit(
            ChangeEmailState(
              status: ChangeEmailStatus.success,
              message:
                  data['message'] ??
                  'Verification code sent to your new email address',
              data: Map<String, dynamic>.from(data['data'] ?? {}),
            ),
          );
        },
      );
    } catch (e) {
      // 6. Handle errors
      _logEvent('email_change_request_failed', {
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
      });

      emit(
        ChangeEmailState(
          status: ChangeEmailStatus.error,
          error: _getErrorMessage(e),
        ),
      );
    }
  }

  Future<void> verifyEmailChange({
    required int requestId,
    required String verificationCode,
  }) async {
    try {
      _logEvent('email_verification_attempted', {'request_id': requestId});

      emit(
        state.copyWith(
          status: ChangeEmailStatus.loading,
          error: null,
          message: null,
        ),
      );

      final result = await _repository.verifyEmailChange(
        requestId: requestId,
        verificationCode: verificationCode,
      );

      result.fold(
        (failure) {
          emit(
            ChangeEmailState(
              status: ChangeEmailStatus.error,
              error: failure.message,
            ),
          );
        },
        (data) {
          _logEvent('email_verification_success', {
            'request_id': requestId,
            'token': data['data']['token'] != null,
          });

          emit(
            ChangeEmailState(
              status: ChangeEmailStatus.verificationSuccess,
              message: data['message'] ?? 'Email verified successfully',
              data: Map<String, dynamic>.from(data['data'] ?? {}),
            ),
          );
        },
      );
    } catch (e) {
      _logEvent('email_verification_failed', {'error': e.toString()});

      emit(
        ChangeEmailState(
          status: ChangeEmailStatus.error,
          error: _getErrorMessage(e),
        ),
      );
    }
  }

  Future<void> confirmEmailChange({required String token}) async {
    try {
      _logEvent('email_confirmation_attempted', {'token_length': token.length});

      emit(
        state.copyWith(
          status: ChangeEmailStatus.loading,
          error: null,
          message: null,
        ),
      );

      final result = await _repository.confirmEmailChange(token: token);

      result.fold(
        (failure) {
          emit(
            ChangeEmailState(
              status: ChangeEmailStatus.error,
              error: failure.message,
            ),
          );
        },
        (data) {
          _logEvent('email_confirmation_success', {});

          emit(
            ChangeEmailState(
              status: ChangeEmailStatus.confirmationSuccess,
              message: data['message'] ?? 'Email changed successfully',
              data: Map<String, dynamic>.from(data['data'] ?? {}),
            ),
          );
        },
      );
    } catch (e) {
      _logEvent('email_confirmation_failed', {'error': e.toString()});

      emit(
        ChangeEmailState(
          status: ChangeEmailStatus.error,
          error: _getErrorMessage(e),
        ),
      );
    }
  }

  Future<void> resendVerificationCode({required int requestId}) async {
    try {
      _logEvent('resend_verification_requested', {'request_id': requestId});

      emit(
        state.copyWith(
          status: ChangeEmailStatus.loading,
          error: null,
          message: null,
        ),
      );

      final result = await _repository.resendVerificationCode(
        requestId: requestId,
      );

      result.fold(
        (failure) {
          emit(
            ChangeEmailState(
              status: ChangeEmailStatus.error,
              error: failure.message,
            ),
          );
        },
        (data) {
          _logEvent('resend_verification_success', {});

          emit(
            ChangeEmailState(
              status: ChangeEmailStatus.success,
              message: data['message'] ?? 'Verification code resent',
              data: Map<String, dynamic>.from(data['data'] ?? {}),
            ),
          );
        },
      );
    } catch (e) {
      _logEvent('resend_verification_failed', {'error': e.toString()});

      emit(
        ChangeEmailState(
          status: ChangeEmailStatus.error,
          error: _getErrorMessage(e),
        ),
      );
    }
  }

  String? _validateRequestInputs({
    required String newEmail,
    required String confirmNewEmail,
    required String password,
  }) {
    // Trim inputs for validation
    final trimmedNew = newEmail.trim();
    final trimmedConfirm = confirmNewEmail.trim();

    // Check for empty fields
    if (trimmedNew.isEmpty || trimmedConfirm.isEmpty || password.isEmpty) {
      return 'All fields are required';
    }

    // Validate email format
    if (!EmailValidator.validate(trimmedNew)) {
      return 'New email is invalid';
    }

    // Check if emails match confirmation
    if (trimmedNew != trimmedConfirm) {
      return 'New emails do not match';
    }

    // Basic password validation
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }

    // Additional security check: prevent common email patterns
    if (_isDisposableEmail(trimmedNew)) {
      return 'Please use a permanent email address';
    }

    return null;
  }

  void reset() {
    emit(const ChangeEmailState());
  }

  // Helper methods

  String _maskEmail(String email) {
    if (email.length < 5) return '***';
    final parts = email.split('@');
    if (parts.length != 2) return '***@***';

    final local = parts[0];
    final domain = parts[1];

    if (local.length <= 2) {
      return '***@$domain';
    }

    final maskedLocal =
        local[0] + '*' * (local.length - 2) + local[local.length - 1];
    return '$maskedLocal@$domain';
  }

  bool _isDisposableEmail(String email) {
    const disposableDomains = [
      'tempmail.com',
      'mailinator.com',
      'guerrillamail.com',
      '10minutemail.com',
      'yopmail.com',
      'throwawaymail.com',
    ];

    final domain = email.split('@').last.toLowerCase();
    return disposableDomains.contains(domain);
  }

  String _getErrorMessage(dynamic e) {
    if (e.toString().contains('timeout') ||
        e.toString().contains('socket') ||
        e.toString().contains('connection')) {
      return 'Network error. Please check your internet connection.';
    } else if (e.toString().contains('422') ||
        e.toString().contains('validation')) {
      return 'Please check your input fields.';
    } else if (e.toString().contains('429')) {
      return 'Too many attempts. Please wait before trying again.';
    } else {
      return 'Failed to process request. Please try again.';
    }
  }

  void _logEvent(String event, Map<String, dynamic> properties) {
    debugPrint('[$_tag] $event: $properties');
  }
}
