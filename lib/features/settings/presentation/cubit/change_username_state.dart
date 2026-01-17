part of 'change_username_cubit.dart';

enum ChangeUsernameStatus { initial, checking, loading, success, error }

class ChangeUsernameState extends Equatable {
  final ChangeUsernameStatus status;
  final String? currentUsername;
  final bool? isUsernameAvailable;
  final List<String> validationErrors;
  final List<String> suggestions;
  final String? error;
  final String? message;
  final Map<String, dynamic>? data;
  final List<Map<String, dynamic>> usernameHistory;
  final DateTime? lastUsernameChange;

  const ChangeUsernameState({
    this.status = ChangeUsernameStatus.initial,
    this.currentUsername,
    this.isUsernameAvailable,
    this.validationErrors = const [],
    this.suggestions = const [],
    this.error,
    this.message,
    this.data,
    this.usernameHistory = const [],
    this.lastUsernameChange,
  });

  bool get canChangeUsername {
    if (lastUsernameChange == null) return true;

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return lastUsernameChange!.isBefore(thirtyDaysAgo);
  }

  String? get cooldownMessage {
    if (lastUsernameChange == null || canChangeUsername) return null;

    final nextChangeDate = lastUsernameChange!.add(const Duration(days: 30));
    final remaining = nextChangeDate.difference(DateTime.now());
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;

    if (days > 0) {
      return 'You can change your username again in $days ${days == 1 ? 'day' : 'days'}';
    } else if (hours > 0) {
      return 'You can change your username again in $hours ${hours == 1 ? 'hour' : 'hours'}';
    } else {
      return 'You can change your username again soon';
    }
  }

  ChangeUsernameState copyWith({
    ChangeUsernameStatus? status,
    String? currentUsername,
    bool? isUsernameAvailable,
    List<String>? validationErrors,
    List<String>? suggestions,
    String? error,
    String? message,
    Map<String, dynamic>? data,
    List<Map<String, dynamic>>? usernameHistory,
    DateTime? lastUsernameChange,
  }) {
    return ChangeUsernameState(
      status: status ?? this.status,
      currentUsername: currentUsername ?? this.currentUsername,
      isUsernameAvailable: isUsernameAvailable ?? this.isUsernameAvailable,
      validationErrors: validationErrors ?? this.validationErrors,
      suggestions: suggestions ?? this.suggestions,
      error: error,
      message: message,
      data: data ?? this.data,
      usernameHistory: usernameHistory ?? this.usernameHistory,
      lastUsernameChange: lastUsernameChange ?? this.lastUsernameChange,
    );
  }

  @override
  List<Object?> get props => [
    status,
    currentUsername,
    isUsernameAvailable,
    validationErrors,
    suggestions,
    error,
    message,
    data,
    usernameHistory,
    lastUsernameChange,
  ];
}
