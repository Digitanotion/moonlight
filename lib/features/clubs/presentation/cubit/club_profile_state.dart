import 'package:equatable/equatable.dart';
import 'package:moonlight/features/clubs/domain/entities/club_profile.dart';

class ClubProfileState extends Equatable {
  final bool loading;
  final bool joining;
  final ClubProfile? profile;
  final String? error;
  final String? success; // Add this

  const ClubProfileState({
    this.loading = false,
    this.joining = false,
    this.profile,
    this.error,
    this.success, // Add this
  });

  ClubProfileState copyWith({
    bool? loading,
    bool? joining,
    ClubProfile? profile,
    String? error,
    String? success, // Add this
  }) {
    return ClubProfileState(
      loading: loading ?? this.loading,
      joining: joining ?? this.joining,
      profile: profile ?? this.profile,
      error: error ?? this.error,
      success: success ?? this.success, // Add this
    );
  }

  @override
  List<Object?> get props => [loading, joining, profile, error, success]; // Add success
}
