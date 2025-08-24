part of 'profile_setup_cubit.dart';

class ProfileSetupState extends Equatable {
  final bool submitting;
  final bool success;
  final String? error;

  final String fullname;
  final String? gender;
  final String? country;
  final String? bio;
  final String? phone;
  final String? avatarPath;
  final DateTime? dob; // UI-only

  final bool loadingCountries;
  final List<String> countries;

  const ProfileSetupState({
    required this.submitting,
    required this.success,
    required this.error,
    required this.fullname,
    required this.gender,
    required this.country,
    required this.bio,
    required this.phone,
    required this.avatarPath,
    required this.dob,
    required this.loadingCountries,
    required this.countries,
  });

  factory ProfileSetupState.initial() => const ProfileSetupState(
    submitting: false,
    success: false,
    error: null,
    fullname: '',
    gender: null,
    country: null,
    bio: null,
    phone: null,
    avatarPath: null,
    dob: null,
    loadingCountries: false,
    countries: <String>[],
  );

  ProfileSetupState copyWith({
    bool? submitting,
    bool? success,
    String? error,
    String? fullname,
    String? gender,
    String? country,
    String? bio,
    String? phone,
    String? avatarPath,
    DateTime? dob,
    bool? loadingCountries,
    List<String>? countries,
  }) => ProfileSetupState(
    submitting: submitting ?? this.submitting,
    success: success ?? this.success,
    error: error,
    fullname: fullname ?? this.fullname,
    gender: gender ?? this.gender,
    country: country ?? this.country,
    bio: bio ?? this.bio,
    phone: phone ?? this.phone,
    avatarPath: avatarPath ?? this.avatarPath,
    dob: dob ?? this.dob,
    loadingCountries: loadingCountries ?? this.loadingCountries,
    countries: countries ?? this.countries,
  );

  @override
  List<Object?> get props => [
    submitting,
    success,
    error,
    fullname,
    gender,
    country,
    bio,
    phone,
    avatarPath,
    dob,
    loadingCountries,
    countries,
  ];
}
