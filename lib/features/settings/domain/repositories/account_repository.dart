import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';

abstract class AccountRepository {
  Future<Either<Failure, void>> deactivate({
    required String confirm, // must be "DEACTIVATE"
    String? password,
    String? reason,
  });

  Future<Either<Failure, void>> reactivate();

  Future<Either<Failure, void>> deleteAccount({
    required String confirm, // must be "DELETE"
    String? password,
  });
}
