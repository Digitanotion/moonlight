part of 'edit_profile_cubit.dart';

class EditProfileState extends Equatable {
  final bool loading;
  final bool submitting;
  final bool success;
  final String? error;

  final String fullname;
  final String? gender;
  final String? country;
  final String? bio;
  final String? phone;

  final String? avatarUrl; // current from server
  final String? avatarPath; // new local file to upload
  final bool removeAvatar;

  final List<String> countries;
  final String? dateOfBirth;

  const EditProfileState({
    required this.loading,
    required this.submitting,
    required this.success,
    required this.error,
    required this.fullname,
    required this.gender,
    required this.country,
    required this.bio,
    required this.phone,
    required this.avatarUrl,
    required this.avatarPath,
    required this.removeAvatar,
    required this.countries,
    required this.dateOfBirth,
  });

  factory EditProfileState.initial() => const EditProfileState(
    loading: false,
    submitting: false,
    success: false,
    error: null,
    fullname: '',
    gender: null,
    country: null,
    bio: null,
    phone: null,
    avatarUrl: null,
    avatarPath: null,
    removeAvatar: false,
    countries: <String>[],
    dateOfBirth: '',
  );

  EditProfileState copyWith({
    bool? loading,
    bool? submitting,
    bool? success,
    String? error,
    String? fullname,
    String? gender,
    String? country,
    String? bio,
    String? phone,
    String? avatarUrl,
    String? avatarPath,
    bool? removeAvatar,
    List<String>? countries,
    String? dateOfBirth,
  }) => EditProfileState(
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    success: success ?? this.success,
    error: error,
    fullname: fullname ?? this.fullname,
    gender: gender ?? this.gender,
    country: country ?? this.country,
    bio: bio ?? this.bio,
    phone: phone ?? this.phone,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    avatarPath: avatarPath ?? this.avatarPath,
    removeAvatar: removeAvatar ?? this.removeAvatar,
    countries: countries ?? this.countries,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
  );

  @override
  List<Object?> get props => [
    loading,
    submitting,
    success,
    error,
    fullname,
    gender,
    country,
    bio,
    phone,
    avatarUrl,
    avatarPath,
    removeAvatar,
    countries,
  ];
}
