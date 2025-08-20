import 'dart:io';

enum Gender { male, female, other, preferNotToSay }

class UserProfile {
  final String? id;
  final String fullName;
  final DateTime? dateOfBirth;
  final String? country;
  final Gender? gender;
  final String? bio;
  final String? profileImageUrl;
  final File? profileImageFile;

  const UserProfile({
    this.id,
    required this.fullName,
    this.dateOfBirth,
    this.country,
    this.gender,
    this.bio,
    this.profileImageUrl,
    this.profileImageFile,
  });

  UserProfile copyWith({
    String? id,
    String? fullName,
    DateTime? dateOfBirth,
    String? country,
    Gender? gender,
    String? bio,
    String? profileImageUrl,
    File? profileImageFile,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      country: country ?? this.country,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profileImageFile: profileImageFile ?? this.profileImageFile,
    );
  }
}
