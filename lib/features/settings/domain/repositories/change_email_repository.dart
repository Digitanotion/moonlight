import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';

abstract class ChangeEmailRepository {
  /// Request email change - sends verification code to new email
  /// Returns request_id for verification step
  Future<Either<Failure, Map<String, dynamic>>> requestEmailChange({
    required String currentEmail,
    required String newEmail,
    required String confirmNewEmail,
    required String password,
  });

  /// Verify the 6-digit code sent to new email
  /// Returns token for confirmation step
  Future<Either<Failure, Map<String, dynamic>>> verifyEmailChange({
    required int requestId,
    required String verificationCode,
  });

  /// Confirm email change with token from verification step
  Future<Either<Failure, Map<String, dynamic>>> confirmEmailChange({
    required String token,
  });

  /// Cancel a pending email change request
  Future<Either<Failure, Map<String, dynamic>>> cancelEmailChange({
    required int requestId,
  });

  /// Resend verification code to new email
  Future<Either<Failure, Map<String, dynamic>>> resendVerificationCode({
    required int requestId,
  });
}
