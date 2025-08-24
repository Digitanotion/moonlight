abstract class ProfileRepository {
  Future<void> setupProfile({
    required String fullname,
    String? gender, // 'male'|'female'|'other'|'prefer_not_to_say'
    String? country,
    String? bio,
    List<String>? interests,
    String? phone,
    String? avatarPath, // optional file path
  });
  Future<Map<String, dynamic>> updateProfile({
    String? fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? interests,
    String? phone,
    String? avatarPath,
    bool removeAvatar = false,
  });

  Future<void> updateInterests(List<String> interests);

  Future<List<String>> getCountries(); // from local asset
}
