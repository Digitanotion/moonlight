import 'package:equatable/equatable.dart';
import '../../domain/entities/suggested_club.dart';

class SuggestedClubsState extends Equatable {
  final bool loading;
  final List<SuggestedClub> clubs;
  final String? error;
  final Set<String> joined;

  const SuggestedClubsState({
    required this.loading,
    required this.clubs,
    this.error,
    required this.joined,
  });

  factory SuggestedClubsState.initial() =>
      const SuggestedClubsState(loading: false, clubs: [], joined: {});

  SuggestedClubsState copyWith({
    bool? loading,
    List<SuggestedClub>? clubs,
    String? error,
    Set<String>? joined,
  }) {
    return SuggestedClubsState(
      loading: loading ?? this.loading,
      clubs: clubs ?? this.clubs,
      error: error,
      joined: joined ?? this.joined,
    );
  }

  @override
  List<Object?> get props => [loading, clubs, error, joined];
}
