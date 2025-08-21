import 'package:equatable/equatable.dart';
import 'package:moonlight/features/profile/domain/entities/interest.dart';

class InterestState extends Equatable {
  final bool loading;
  final List<Interest> interests;
  final Set<String> selectedIds;
  final String? error;
  final bool saved;
  final bool hasCompletedSelection;

  const InterestState({
    required this.loading,
    required this.interests,
    required this.selectedIds,
    required this.error,
    required this.saved,
    required this.hasCompletedSelection,
  });

  factory InterestState.initial() => const InterestState(
    loading: false,
    interests: [],
    selectedIds: {},
    error: null,
    saved: false,
    hasCompletedSelection: false,
  );

  InterestState copyWith({
    bool? loading,
    List<Interest>? interests,
    Set<String>? selectedIds,
    String? error,
    bool? saved,
    bool? hasCompletedSelection,
  }) {
    return InterestState(
      loading: loading ?? this.loading,
      interests: interests ?? this.interests,
      selectedIds: selectedIds ?? this.selectedIds,
      error: error,
      saved: saved ?? this.saved,
      hasCompletedSelection:
          hasCompletedSelection ?? this.hasCompletedSelection,
    );
  }

  @override
  List<Object?> get props => [loading, interests, selectedIds, error, saved];
}
