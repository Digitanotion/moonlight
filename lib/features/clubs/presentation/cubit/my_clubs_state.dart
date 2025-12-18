import 'package:equatable/equatable.dart';
import '../../domain/entities/club.dart';

class MyClubsState extends Equatable {
  final bool loading;
  final List<Club> clubs;
  final String? error;

  const MyClubsState({required this.loading, required this.clubs, this.error});

  factory MyClubsState.initial() =>
      const MyClubsState(loading: false, clubs: [], error: null);

  MyClubsState copyWith({bool? loading, List<Club>? clubs, String? error}) {
    return MyClubsState(
      loading: loading ?? this.loading,
      clubs: clubs ?? this.clubs,
      error: error,
    );
  }

  @override
  List<Object?> get props => [loading, clubs, error];
}
