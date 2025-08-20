import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/profile_setup/domain/entities/user_profile.dart';

abstract class ProfileRepository {
  Future<Either<Failure, List<String>>> getCountries();
  Future<Either<Failure, void>> updateProfile(UserProfile profile);
}
