// check_auth_status.dart
import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/auth/domain/repositories/auth_repository.dart';

class CheckAuthStatus {
  final AuthRepository repository;

  CheckAuthStatus(this.repository);

  Future<Either<Failure, bool>> call() async {
    return await repository.isLoggedIn();
  }
}

// logout.dart
class Logout {
  final AuthRepository repository;

  Logout(this.repository);

  Future<Either<Failure, void>> call() async {
    return await repository.logout();
  }
}
