part of 'profile_setup_bloc.dart';

enum ProfileSetupStatus { initial, loading, success, failure }

class ProfileSetupState extends Equatable {
  final ProfileSetupStatus status;
  final UserProfile profile;
  final List<String> countries;
  final String? errorMessage;

  const ProfileSetupState({
    this.status = ProfileSetupStatus.initial,
    required this.profile,
    this.countries = const [],
    this.errorMessage,
  });

  ProfileSetupState copyWith({
    ProfileSetupStatus? status,
    UserProfile? profile,
    List<String>? countries,
    String? errorMessage,
  }) {
    return ProfileSetupState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      countries: countries ?? this.countries,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, profile, countries, errorMessage];
}
