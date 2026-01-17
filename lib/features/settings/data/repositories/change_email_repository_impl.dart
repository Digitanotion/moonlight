import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/settings/data/datasources/change_email_remote_datasource.dart';
import 'package:moonlight/features/settings/domain/repositories/change_email_repository.dart';

class ChangeEmailRepositoryImpl implements ChangeEmailRepository {
  final ChangeEmailRemoteDataSource _remoteDataSource;

  ChangeEmailRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, Map<String, dynamic>>> requestEmailChange({
    required String currentEmail,
    required String newEmail,
    required String confirmNewEmail,
    required String password,
  }) async {
    try {
      final response = await _remoteDataSource.requestEmailChange(
        newEmail: newEmail,
        confirmNewEmail: confirmNewEmail,
        password: password,
      );
      return Right(response);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> verifyEmailChange({
    required int requestId,
    required String verificationCode,
  }) async {
    try {
      final response = await _remoteDataSource.verifyEmailChange(
        requestId: requestId,
        verificationCode: verificationCode,
      );
      return Right(response);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> confirmEmailChange({
    required String token,
  }) async {
    try {
      final response = await _remoteDataSource.confirmEmailChange(token: token);
      return Right(response);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> cancelEmailChange({
    required int requestId,
  }) async {
    try {
      final response = await _remoteDataSource.cancelEmailChange(
        requestId: requestId,
      );
      return Right(response);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> resendVerificationCode({
    required int requestId,
  }) async {
    try {
      final response = await _remoteDataSource.resendVerificationCode(
        requestId: requestId,
      );
      return Right(response);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
