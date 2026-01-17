// lib/features/settings/presentation/cubit/account_settings_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/settings/domain/entities/notification_settings.dart';
import 'package:moonlight/features/settings/domain/repositories/account_repository.dart';

enum SettingsStatus { idle, loading, success, failure, deleted }

class AccountSettingsState extends Equatable {
  final SettingsStatus status;
  final String? error;

  // Notification settings from API
  final bool pushEnabled;
  final bool emailEnabled;
  final bool liveAlertsEnabled;
  final bool giftAlertsEnabled;
  final bool messageNotifications;
  final bool followNotifications;
  final bool clubNotifications;

  // Account status
  final bool isDeactivated;

  // Deletion status (new fields)
  final Map<String, dynamic>? deletionStatus;
  final bool isDeletionLoading;
  final String? deletionError;
  final bool deletionRequested;
  final bool deletionCancelled;

  const AccountSettingsState({
    this.status = SettingsStatus.idle,
    this.error,
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.liveAlertsEnabled = true,
    this.giftAlertsEnabled = true,
    this.messageNotifications = true,
    this.followNotifications = true,
    this.clubNotifications = true,
    this.isDeactivated = false,
    this.deletionStatus,
    this.isDeletionLoading = false,
    this.deletionError,
    this.deletionRequested = false,
    this.deletionCancelled = false,
  });

  // Computed properties for easy access
  bool get hasPendingDeletion =>
      deletionStatus?['has_pending_deletion'] == true;

  int get daysRemaining => deletionStatus?['days_remaining'].toInt() ?? 0;

  bool get canCancelDeletion => deletionStatus?['can_cancel'] == true;

  String? get scheduledDeletionDate => deletionStatus?['deletion_scheduled_at'];

  int get gracePeriodDays => deletionStatus?['grace_period_days'] ?? 30;

  AccountSettingsState copyWith({
    SettingsStatus? status,
    String? error,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? liveAlertsEnabled,
    bool? giftAlertsEnabled,
    bool? messageNotifications,
    bool? followNotifications,
    bool? clubNotifications,
    bool? isDeactivated,
    Map<String, dynamic>? deletionStatus,
    bool? isDeletionLoading,
    String? deletionError,
    bool? deletionRequested,
    bool? deletionCancelled,
  }) {
    return AccountSettingsState(
      status: status ?? this.status,
      error: error ?? this.error,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      liveAlertsEnabled: liveAlertsEnabled ?? this.liveAlertsEnabled,
      giftAlertsEnabled: giftAlertsEnabled ?? this.giftAlertsEnabled,
      messageNotifications: messageNotifications ?? this.messageNotifications,
      followNotifications: followNotifications ?? this.followNotifications,
      clubNotifications: clubNotifications ?? this.clubNotifications,
      isDeactivated: isDeactivated ?? this.isDeactivated,
      deletionStatus: deletionStatus ?? this.deletionStatus,
      isDeletionLoading: isDeletionLoading ?? this.isDeletionLoading,
      deletionError: deletionError,
      deletionRequested: deletionRequested ?? this.deletionRequested,
      deletionCancelled: deletionCancelled ?? this.deletionCancelled,
    );
  }

  @override
  List<Object?> get props => [
    status,
    error,
    pushEnabled,
    emailEnabled,
    liveAlertsEnabled,
    giftAlertsEnabled,
    messageNotifications,
    followNotifications,
    clubNotifications,
    isDeactivated,
    deletionStatus,
    isDeletionLoading,
    deletionError,
    deletionRequested,
    deletionCancelled,
  ];
}

class AccountSettingsCubit extends Cubit<AccountSettingsState> {
  final AccountRepository repository;
  final SharedPreferences prefs;

  AccountSettingsCubit({required this.repository, required this.prefs})
    : super(const AccountSettingsState()) {
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    // Load notification settings
    await fetchNotificationSettings();

    // Load deletion status if user is authenticated
    await fetchDeletionStatus();
  }

  // ============ NOTIFICATION SETTINGS ============

  Future<void> fetchNotificationSettings() async {
    emit(state.copyWith(status: SettingsStatus.loading, error: null));

    final result = await repository.getNotificationSettings();

    result.fold(
      (failure) {
        // If API fails, fall back to local storage or defaults
        emit(
          state.copyWith(
            status: SettingsStatus.idle,
            error: null, // Don't show error for initial load
          ),
        );
      },
      (settings) {
        // Update state with API data
        emit(
          state.copyWith(
            status: SettingsStatus.idle,
            pushEnabled: settings.pushEnabled,
            emailEnabled: settings.emailEnabled,
            liveAlertsEnabled: settings.liveAlertsEnabled,
            giftAlertsEnabled: settings.giftAlertsEnabled,
            messageNotifications: settings.messageNotifications,
            followNotifications: settings.followNotifications,
            clubNotifications: settings.clubNotifications,
          ),
        );
      },
    );
  }

  Future<void> togglePush(bool value) async {
    await _updateNotificationSetting(
      'push',
      value,
      (state) => state.copyWith(pushEnabled: value),
    );
  }

  Future<void> toggleEmail(bool value) async {
    await _updateNotificationSetting(
      'email',
      value,
      (state) => state.copyWith(emailEnabled: value),
    );
  }

  Future<void> toggleLiveAlerts(bool value) async {
    await _updateNotificationSetting(
      'liveAlerts',
      value,
      (state) => state.copyWith(liveAlertsEnabled: value),
    );
  }

  Future<void> toggleGiftAlerts(bool value) async {
    await _updateNotificationSetting(
      'giftAlerts',
      value,
      (state) => state.copyWith(giftAlertsEnabled: value),
    );
  }

  Future<void> _updateNotificationSetting(
    String settingName,
    bool value,
    AccountSettingsState Function(AccountSettingsState) stateUpdate,
  ) async {
    // Optimistic update
    final previousState = state;
    emit(stateUpdate(state));

    // Create updated settings object
    final settings = NotificationSettings(
      pushEnabled: settingName == 'push' ? value : state.pushEnabled,
      emailEnabled: settingName == 'email' ? value : state.emailEnabled,
      liveAlertsEnabled: settingName == 'liveAlerts'
          ? value
          : state.liveAlertsEnabled,
      giftAlertsEnabled: settingName == 'giftAlerts'
          ? value
          : state.giftAlertsEnabled,
      messageNotifications: state.messageNotifications,
      followNotifications: state.followNotifications,
      clubNotifications: state.clubNotifications,
    );

    final result = await repository.updateNotificationSettings(settings);

    result.fold(
      (failure) {
        // Revert on failure
        emit(
          previousState.copyWith(
            status: SettingsStatus.failure,
            error: failure.message,
          ),
        );

        // Clear error after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (state.status == SettingsStatus.failure) {
            emit(
              previousState.copyWith(status: SettingsStatus.idle, error: null),
            );
          }
        });
      },
      (_) {
        // Success - update with API response
        emit(state.copyWith(status: SettingsStatus.success));

        // Clear success after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (state.status == SettingsStatus.success) {
            emit(state.copyWith(status: SettingsStatus.idle));
          }
        });
      },
    );
  }

  // ============ ACCOUNT DEACTIVATION/REACTIVATION ============

  Future<void> performDeactivate({String? password, String? reason}) async {
    emit(state.copyWith(status: SettingsStatus.loading, error: null));

    final res = await repository.deactivate(
      confirm: 'DEACTIVATE',
      password: password,
      reason: reason,
    );

    res.fold(
      (failure) => emit(
        state.copyWith(status: SettingsStatus.failure, error: failure.message),
      ),
      (_) {
        emit(
          state.copyWith(status: SettingsStatus.success, isDeactivated: true),
        );

        // Clear success after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (state.status == SettingsStatus.success) {
            emit(state.copyWith(status: SettingsStatus.idle));
          }
        });
      },
    );
  }

  Future<void> performReactivate() async {
    emit(state.copyWith(status: SettingsStatus.loading, error: null));

    final res = await repository.reactivate();

    res.fold(
      (failure) => emit(
        state.copyWith(status: SettingsStatus.failure, error: failure.message),
      ),
      (_) {
        emit(
          state.copyWith(status: SettingsStatus.success, isDeactivated: false),
        );

        // Clear success after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (state.status == SettingsStatus.success) {
            emit(state.copyWith(status: SettingsStatus.idle));
          }
        });
      },
    );
  }

  // ============ ACCOUNT DELETION FLOW (NEW) ============

  /// Fetch current deletion status from server
  Future<void> fetchDeletionStatus() async {
    emit(state.copyWith(isDeletionLoading: true, deletionError: null));

    final result = await repository.getDeletionStatus();

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isDeletionLoading: false,
            deletionError: failure.message,
          ),
        );
      },
      (status) {
        emit(
          state.copyWith(
            isDeletionLoading: false,
            deletionStatus: status,
            deletionError: null,
          ),
        );
      },
    );
  }

  /// Request account deletion with grace period
  Future<void> requestAccountDeletion({
    required String password,
    required String reason,
    String? feedback,
  }) async {
    emit(
      state.copyWith(
        status: SettingsStatus.loading,
        error: null,
        deletionError: null,
      ),
    );

    final result = await repository.requestDeletion(
      confirm: 'DELETE',
      password: password,
      reason: reason,
      feedback: feedback,
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: SettingsStatus.failure,
            error: failure.message,
            deletionError: failure.message,
          ),
        );
      },
      (_) {
        // Success - refresh deletion status
        fetchDeletionStatus();
        emit(
          state.copyWith(
            status: SettingsStatus.success,
            deletionRequested: true,
            deletionError: null,
          ),
        );

        // Clear success state after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          emit(
            state.copyWith(
              status: SettingsStatus.idle,
              deletionRequested: false,
            ),
          );
        });
      },
    );
  }

  /// Cancel pending account deletion
  Future<void> cancelAccountDeletion() async {
    emit(
      state.copyWith(
        status: SettingsStatus.loading,
        error: null,
        deletionError: null,
      ),
    );

    final result = await repository.cancelDeletion(confirm: 'CANCEL_DELETE');

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: SettingsStatus.failure,
            error: failure.message,
            deletionError: failure.message,
          ),
        );
      },
      (_) {
        // Success - refresh deletion status
        fetchDeletionStatus();
        emit(
          state.copyWith(
            status: SettingsStatus.success,
            deletionCancelled: true,
            deletionError: null,
          ),
        );

        // Clear success state after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          emit(
            state.copyWith(
              status: SettingsStatus.idle,
              deletionCancelled: false,
            ),
          );
        });
      },
    );
  }

  /// Immediate account deletion (no grace period) - Legacy method
  Future<void> performImmediateDelete({String? password}) async {
    emit(state.copyWith(status: SettingsStatus.loading, error: null));

    final res = await repository.deleteAccount(
      confirm: 'DELETE',
      password: password,
    );

    res.fold(
      (failure) => emit(
        state.copyWith(status: SettingsStatus.failure, error: failure.message),
      ),
      (_) {
        // let the page listener navigate out and clear local state using your existing logout flow
        emit(state.copyWith(status: SettingsStatus.deleted));
      },
    );
  }

  /// Immediate account deletion for admin users (super admin flow)
  Future<void> performAdminImmediateDelete({required String password}) async {
    emit(state.copyWith(status: SettingsStatus.loading, error: null));

    // Note: You'll need to add an admin immediate delete endpoint in backend
    // For now, using the same as regular delete
    final res = await repository.deleteAccount(
      confirm: 'DELETE',
      password: password,
    );

    res.fold(
      (failure) => emit(
        state.copyWith(status: SettingsStatus.failure, error: failure.message),
      ),
      (_) {
        emit(state.copyWith(status: SettingsStatus.deleted));
      },
    );
  }

  // ============ UTILITY METHODS ============

  /// Clear all errors
  void clearErrors() {
    emit(state.copyWith(error: null, deletionError: null));
  }

  /// Reset deletion state
  void resetDeletionState() {
    emit(
      state.copyWith(
        deletionRequested: false,
        deletionCancelled: false,
        deletionError: null,
      ),
    );
  }

  /// Check if user needs password for account actions
  /// You'll need to implement this based on your auth system
  Future<bool> checkIfPasswordRequired() async {
    // Implement based on your auth system
    // For example: check if user is local (email/password) vs OAuth
    return await prefs.getBool('is_local_user') ?? true;
  }

  Future<void> performDelete({String? password}) async {
    // This is for backward compatibility with existing UI
    return performImmediateDelete(password: password);
  }
}
