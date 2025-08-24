import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../repositories/account_repository.dart';

class ReactivateAccount {
  final AccountRepository repo;
  ReactivateAccount(this.repo);

  Future<Either<Failure, void>> call() async {
    try {
      await repo.reactivate();
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(_dioMsg(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

String _dioMsg(DioException e) =>
    e.response?.data is Map &&
        (e.response!.data['message']?.toString().isNotEmpty ?? false)
    ? e.response!.data['message'].toString()
    : e.message ?? 'Network error';
