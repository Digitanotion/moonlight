import 'package:equatable/equatable.dart';

class AccountSettingsState extends Equatable {
  final bool loading;
  final String? error;
  final bool deactivated; // true if user just deactivated
  final bool deleted; // true if user just deleted
  final bool reactivated; // true if user just reactivated

  const AccountSettingsState({
    this.loading = false,
    this.error,
    this.deactivated = false,
    this.deleted = false,
    this.reactivated = false,
  });

  AccountSettingsState copyWith({
    bool? loading,
    String? error,
    bool? deactivated,
    bool? deleted,
    bool? reactivated,
  }) {
    return AccountSettingsState(
      loading: loading ?? this.loading,
      error: error,
      deactivated: deactivated ?? this.deactivated,
      deleted: deleted ?? this.deleted,
      reactivated: reactivated ?? this.reactivated,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    error,
    deactivated,
    deleted,
    reactivated,
  ];
}
