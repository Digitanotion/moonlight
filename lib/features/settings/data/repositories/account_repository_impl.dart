import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/account_remote_data_source.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AccountRemoteDataSource remote;
  AccountRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, void>> deactivate({
    required String confirm,
    String? password,
    String? reason,
  }) async {
    try {
      await remote.deactivate(
        confirm: confirm,
        password: password,
        reason: reason,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> reactivate() async {
    try {
      await remote.reactivate();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount({
    required String confirm,
    String? password,
  }) async {
    try {
      await remote.deleteAccount(confirm: confirm, password: password);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
