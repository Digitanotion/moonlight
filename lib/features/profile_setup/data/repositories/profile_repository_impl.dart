import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/profile_setup/data/datasources/profile_remote_data_source.dart';
import 'package:moonlight/features/profile_setup/domain/entities/user_profile.dart';
import 'package:moonlight/features/profile_setup/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  ProfileRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<String>>> getCountries() async {
    try {
      final countries = await remoteDataSource.getCountries();
      return Right(countries);
    } on ServerException {
      return Left(ServerFailure("Server failed to get countries"));
    }
  }

  @override
  Future<Either<Failure, void>> updateProfile(UserProfile profile) async {
    try {
      // First upload image if exists
      String? imageUrl = profile.profileImageUrl;
      if (profile.profileImageFile != null) {
        // This would typically upload to a cloud storage service
        // For now, we'll simulate the upload
        await Future.delayed(const Duration(seconds: 2));
        imageUrl =
            'https://example.com/profile_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      }

      final profileData = _profileToMap(
        profile.copyWith(profileImageUrl: imageUrl),
      );
      await remoteDataSource.updateProfile(profileData);
      return const Right(null);
    } on ServerException {
      return Left(ServerFailure("Server failed to updated profile"));
    }
  }

  Map<String, dynamic> _profileToMap(UserProfile profile) {
    return {
      'full_name': profile.fullName,
      'date_of_birth': profile.dateOfBirth?.toIso8601String(),
      'country': profile.country,
      'gender': profile.gender?.toString().split('.').last,
      'bio': profile.bio,
    };
  }
}
