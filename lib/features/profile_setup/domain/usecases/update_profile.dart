import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/profile_setup/domain/entities/user_profile.dart';
import 'package:moonlight/features/profile_setup/domain/repositories/profile_repository.dart';

class UpdateProfile {
  final ProfileRepository repository;

  UpdateProfile(this.repository);

  Future<Either<Failure, void>> call(UserProfile profile) async {
    return await repository.updateProfile(profile);
  }
}
