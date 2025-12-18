import 'package:moonlight/features/clubs/domain/entities/club.dart';

class DiscoverClubsState {
  final bool loading;
  final List<Club> clubs;
  final Set<String> joining;
  final String? errorMessage;
  final String? successMessage;

  DiscoverClubsState({
    required this.loading,
    required this.clubs,
    required this.joining,
    this.errorMessage,
    this.successMessage,
  });

  factory DiscoverClubsState.initial() =>
      DiscoverClubsState(loading: true, clubs: const [], joining: <String>{});

  DiscoverClubsState copyWith({
    bool? loading,
    List<Club>? clubs,
    Set<String>? joining,
    String? errorMessage,
    String? successMessage,
  }) {
    return DiscoverClubsState(
      loading: loading ?? this.loading,
      clubs: clubs ?? this.clubs,
      joining: joining ?? this.joining,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  ///AASS
}
