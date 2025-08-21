import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../repositories/interest_repository.dart';

class HasCompletedSelection {
  final InterestRepository repository;
  HasCompletedSelection(this.repository);

  Future<Either<Failure, bool>> call() {
    return repository.hasCompletedSelection();
  }
}
