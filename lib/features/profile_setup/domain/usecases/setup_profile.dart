import '../repositories/profile_repository.dart';

class SetupProfile {
  final ProfileRepository repo;
  SetupProfile(this.repo);

  Future<void> call({
    required String fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? interests,
    String? phone,
    String? avatarPath,
  }) => repo.setupProfile(
    fullname: fullname,
    gender: gender,
    country: country,
    bio: bio,
    interests: interests,
    phone: phone,
    avatarPath: avatarPath,
  );
}
