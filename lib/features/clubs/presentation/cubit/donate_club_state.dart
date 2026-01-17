part of 'donate_club_cubit.dart';

class DonateClubState {
  final bool loading;
  final bool success;
  final String? error;
  final int? balance;

  const DonateClubState({
    required this.loading,
    required this.success,
    this.error,
    this.balance,
  });

  const DonateClubState.initial()
    : loading = false,
      success = false,
      error = null,
      balance = 0;

  DonateClubState copyWith({
    bool? loading,
    bool? success,
    String? error,
    int? balance,
  }) {
    return DonateClubState(
      loading: loading ?? this.loading,
      success: success ?? this.success,
      error: error,
      balance: balance ?? this.balance,
    );
  }
}
