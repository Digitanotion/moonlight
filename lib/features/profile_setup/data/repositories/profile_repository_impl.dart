import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/auth/data/models/user_model.dart';

import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';
import '../datasources/country_local_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remote;
  final CountryLocalDataSource countryLocal;
  final AuthLocalDataSource local;

  ProfileRepositoryImpl({
    required this.remote,
    required this.countryLocal,
    required this.local,
  });

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
  Future<UserModel> fetchMyProfile() async {
    final map = await remote.getMe(); // UserResource map
    final user = UserModel.fromUserResource(map);
    // cache locally so the rest of the app sees the latest profile
    try {
      // ✅ cache locally (SharedPreferences under the hood)
      await local.cacheUser(user);
    } catch (_) {}
    return user;
  }

  @override
  Future<List<String>> getCountries() => countryLocal.loadCountries();
}
