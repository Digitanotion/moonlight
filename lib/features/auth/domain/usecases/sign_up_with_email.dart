import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/auth/domain/repositories/auth_repository.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';

class SignUpWithEmail {
  final AuthRepository repository;

  SignUpWithEmail(this.repository);

  Future<Either<Failure, User>> call({
    required String email,
    required String password,
    String? name,
  }) async {
    return await repository.signUpWithEmail(
      email: email,
      password: password,
      name: name,
    );
  }
}
