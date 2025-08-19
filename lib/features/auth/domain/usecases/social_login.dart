import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/auth/domain/repositories/auth_repository.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';

class SocialLogin {
  final AuthRepository repository;

  SocialLogin(this.repository);

  Future<Either<Failure, User>> call(String provider) async {
    return await repository.socialLogin(provider);
  }
}
