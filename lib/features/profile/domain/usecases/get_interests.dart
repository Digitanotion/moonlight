import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../entities/interest.dart';
import '../repositories/interest_repository.dart';

class GetInterests {
  final InterestRepository repository;
  GetInterests(this.repository);

  Future<Either<Failure, List<Interest>>> call() {
    return repository.getInterests();
  }
}
