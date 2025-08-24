part of 'user_interest_cubit.dart';

class UserInterestState extends Equatable {
  final List<String> selected;
  final bool submitting;
  final bool success;
  final String? error;

  const UserInterestState({
    required this.selected,
    required this.submitting,
    required this.success,
    required this.error,
  });

  factory UserInterestState.initial() => const UserInterestState(
    selected: [],
    submitting: false,
    success: false,
    error: null,
  );

  UserInterestState copyWith({
    List<String>? selected,
    bool? submitting,
    bool? success,
    String? error,
  }) => UserInterestState(
    selected: selected ?? this.selected,
    submitting: submitting ?? this.submitting,
    success: success ?? this.success,
    error: error,
  );

  @override
  List<Object?> get props => [selected, submitting, success, error];
}
