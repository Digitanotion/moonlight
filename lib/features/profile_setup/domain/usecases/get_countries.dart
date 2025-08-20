import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/profile_setup/domain/repositories/profile_repository.dart';

class GetCountries {
  final ProfileRepository repository;

  GetCountries(this.repository);

  Future<Either<Failure, List<String>>> call() async {
    return await repository.getCountries();
  }
}
