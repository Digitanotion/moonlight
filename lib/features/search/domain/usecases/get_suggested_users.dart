import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';
import 'package:moonlight/features/search/domain/repositories/search_repository.dart';

class GetSuggestedUsers {
  final SearchRepository repository;

  GetSuggestedUsers(this.repository);

  Future<Either<Failure, List<UserResult>>> call() async {
    return await repository.getSuggestedUsers();
  }
}
