import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../entities/interest.dart';

abstract class InterestRepository {
  Future<Either<Failure, List<Interest>>> getInterests();
  Future<Either<Failure, Unit>> saveUserInterests(List<String> selectedIds);
  Future<Either<Failure, bool>> hasCompletedSelection();
}
