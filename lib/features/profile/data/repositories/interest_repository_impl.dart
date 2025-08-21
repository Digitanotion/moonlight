import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../../domain/entities/interest.dart';
import '../../domain/repositories/interest_repository.dart';
import '../datasources/interests_local_data_source.dart';
import '../datasources/interests_remote_data_source.dart';

class InterestRepositoryImpl implements InterestRepository {
  final InterestsRemoteDataSource remote;
  final InterestsLocalDataSource local;

  InterestRepositoryImpl({required this.remote, required this.local});

  @override
  Future<Either<Failure, List<Interest>>> getInterests() async {
    try {
      final result = await remote.fetchInterests();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure("Failed to get interests"));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveUserInterests(
    List<String> selectedIds,
  ) async {
    try {
      await remote.saveUserInterests(selectedIds);
      await local.setCompleted(true);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure("Failed to save user interests"));
    }
  }

  @override
  Future<Either<Failure, bool>> hasCompletedSelection() async {
    try {
      final done = await local.getCompleted();
      return Right(done);
    } catch (e) {
      return Left(CacheFailure("Failed to cache completed selection"));
    }
  }
}
