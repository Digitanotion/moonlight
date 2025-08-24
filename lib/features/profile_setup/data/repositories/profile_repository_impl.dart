import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';
import '../datasources/country_local_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remote;
  final CountryLocalDataSource countryLocal;

  ProfileRepositoryImpl({required this.remote, required this.countryLocal});

  @override
  Future<void> setupProfile({
    required String fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? interests,
    String? phone,
    String? avatarPath,
  }) => remote.setupProfile(
    fullname: fullname,
    gender: gender,
    country: country,
    bio: bio,
    interests: interests,
    phone: phone,
    avatarPath: avatarPath,
  );

  @override
  Future<void> updateInterests(List<String> interests) =>
      remote.updateInterests(interests);

  @override
  Future<Map<String, dynamic>> updateProfile({
    String? fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? interests,
    String? phone,
    String? avatarPath,
    bool removeAvatar = false,
  }) => remote.updateProfile(
    fullname: fullname,
    gender: gender,
    country: country,
    bio: bio,
    interests: interests,
    phone: phone,
    avatarPath: avatarPath,
    removeAvatar: removeAvatar,
  );

  @override
  Future<List<String>> getCountries() => countryLocal.loadCountries();
}
