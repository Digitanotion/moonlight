import 'package:equatable/equatable.dart';
import 'package:moonlight/features/clubs/domain/entities/club_profile.dart';

class ClubProfileState extends Equatable {
  final bool loading;
  final ClubProfile? profile;
  final String? error;

  const ClubProfileState({this.loading = false, this.profile, this.error});

  ClubProfileState copyWith({
    bool? loading,
    ClubProfile? profile,
    String? error,
  }) {
    return ClubProfileState(
      loading: loading ?? this.loading,
      profile: profile ?? this.profile,
      error: error,
    );
  }

  @override
  List<Object?> get props => [loading, profile, error];
}
