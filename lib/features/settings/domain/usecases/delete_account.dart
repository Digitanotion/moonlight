import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../repositories/account_repository.dart';

class DeleteAccount {
  final AccountRepository repo;
  DeleteAccount(this.repo);

  /// confirm must be "DELETE" per API
  Future<Either<Failure, void>> call({
    required String confirm,
    String? password,
  }) async {
    try {
      await repo.deleteAccount(confirm: confirm, password: password);
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
