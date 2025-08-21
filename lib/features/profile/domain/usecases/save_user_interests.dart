import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../repositories/interest_repository.dart';

class SaveUserInterests {
  final InterestRepository repository;
  SaveUserInterests(this.repository);

  Future<Either<Failure, Unit>> call(List<String> ids) {
    return repository.saveUserInterests(ids);
  }
}
