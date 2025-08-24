import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../repositories/account_repository.dart';

class DeactivateAccount {
  final AccountRepository repo;
  DeactivateAccount(this.repo);

  Future<Either<Failure, void>> call({
    required String confirm,
    String? password,
    String? reason,
  }) {
    return repo.deactivate(
      confirm: confirm,
      password: password,
      reason: reason,
    );
  }
}
