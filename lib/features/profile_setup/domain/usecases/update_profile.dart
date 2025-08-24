import '../repositories/profile_repository.dart';

class UpdateProfile {
  final ProfileRepository repo;
  UpdateProfile(this.repo);

  Future<Map<String, dynamic>> call({
    String? fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? interests,
    String? phone,
    String? avatarPath,
    bool removeAvatar = false,
  }) {
    return repo.updateProfile(
      fullname: fullname,
      gender: gender,
      country: country,
      bio: bio,
      interests: interests,
      phone: phone,
      avatarPath: avatarPath,
      removeAvatar: removeAvatar,
    );
  }
}
