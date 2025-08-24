import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, bool>> isLoggedIn();
  Future<Either<Failure, User>> getCurrentUser();
  Future<Either<Failure, User>> loginWithEmail(String email, String password);
  Future<Either<Failure, User>> signUpWithEmail({
    required String email,
    required String password,
    String? agent_name,
  });
  Future<Either<Failure, User>> socialLogin(String provider);
  Future<Either<Failure, User>> loginWithGoogle();
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, String>> getAuthToken();
  Future<Either<Failure, String>> forgotPassword(String email);
}
