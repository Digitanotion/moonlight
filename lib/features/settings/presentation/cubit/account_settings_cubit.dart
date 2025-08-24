import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../../domain/usecases/deactivate_account.dart';
import '../../domain/usecases/reactivate_account.dart';
import '../../domain/usecases/delete_account.dart';

enum SettingsStatus { idle, loading, success, failure, deleted }

class AccountSettingsState extends Equatable {
  final SettingsStatus status;
  final String? error;

  // UI toggles (local only for now; easy to replace with API later)
  final bool pushEnabled;
  final bool emailEnabled;
  final bool liveAlertsEnabled;
  final bool giftAlertsEnabled;

  // whether server says user is deactivated (we toggle it based on action)
  final bool isDeactivated;

  const AccountSettingsState({
    this.status = SettingsStatus.idle,
    this.error,
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.liveAlertsEnabled = true,
    this.giftAlertsEnabled = true,
    this.isDeactivated = false,
  });

  AccountSettingsState copyWith({
    SettingsStatus? status,
    String? error,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? liveAlertsEnabled,
    bool? giftAlertsEnabled,
    bool? isDeactivated,
  }) {
    return AccountSettingsState(
      status: status ?? this.status,
      error: error,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      liveAlertsEnabled: liveAlertsEnabled ?? this.liveAlertsEnabled,
      giftAlertsEnabled: giftAlertsEnabled ?? this.giftAlertsEnabled,
      isDeactivated: isDeactivated ?? this.isDeactivated,
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
    isDeactivated,
  ];
}

class AccountSettingsCubit extends Cubit<AccountSettingsState> {
  final DeactivateAccount deactivateAccount;
  final ReactivateAccount reactivateAccount;
  final DeleteAccount deleteAccount;
  final SharedPreferences prefs;

  AccountSettingsCubit({
    required this.deactivateAccount,
    required this.reactivateAccount,
    required this.deleteAccount,
    required this.prefs,
  }) : super(const AccountSettingsState()) {
    _hydrateToggles();
  }

  static const _kPush = 'settings_push';
  static const _kEmail = 'settings_email';
  static const _kLive = 'settings_live';
  static const _kGift = 'settings_gift';
  static const _kDeactivated = 'settings_is_deactivated';

  void _hydrateToggles() {
    emit(
      state.copyWith(
        pushEnabled: prefs.getBool(_kPush) ?? true,
        emailEnabled: prefs.getBool(_kEmail) ?? true,
        liveAlertsEnabled: prefs.getBool(_kLive) ?? true,
        giftAlertsEnabled: prefs.getBool(_kGift) ?? true,
        isDeactivated: prefs.getBool(_kDeactivated) ?? false,
      ),
    );
  }

  void togglePush(bool v) {
    prefs.setBool(_kPush, v);
    emit(state.copyWith(pushEnabled: v));
  }

  void toggleEmail(bool v) {
    prefs.setBool(_kEmail, v);
    emit(state.copyWith(emailEnabled: v));
  }

  void toggleLiveAlerts(bool v) {
    prefs.setBool(_kLive, v);
    emit(state.copyWith(liveAlertsEnabled: v));
  }

  void toggleGiftAlerts(bool v) {
    prefs.setBool(_kGift, v);
    emit(state.copyWith(giftAlertsEnabled: v));
  }

  Future<void> performDeactivate({String? password, String? reason}) async {
    emit(state.copyWith(status: SettingsStatus.loading, error: null));
    final Either<Failure, void> res = await deactivateAccount(
      confirm: 'DEACTIVATE',
      password: password,
      reason: reason,
    );
    res.fold(
      (l) => emit(
        state.copyWith(status: SettingsStatus.failure, error: l.message),
      ),
      (_) {
        prefs.setBool(_kDeactivated, true);
        emit(
          state.copyWith(status: SettingsStatus.success, isDeactivated: true),
        );
      },
    );
  }

  Future<void> performReactivate() async {
    emit(state.copyWith(status: SettingsStatus.loading, error: null));
    final res = await reactivateAccount();
    res.fold(
      (l) => emit(
        state.copyWith(status: SettingsStatus.failure, error: l.message),
      ),
      (_) {
        prefs.setBool(_kDeactivated, false);
        emit(
          state.copyWith(status: SettingsStatus.success, isDeactivated: false),
        );
      },
    );
  }

  Future<void> performDelete({String? password}) async {
    emit(state.copyWith(status: SettingsStatus.loading, error: null));
    final res = await deleteAccount(confirm: 'DELETE', password: password);
    res.fold(
      (l) => emit(
        state.copyWith(status: SettingsStatus.failure, error: l.message),
      ),
      (_) {
        // let the page listener navigate out and clear local state using your existing logout flow
        emit(state.copyWith(status: SettingsStatus.deleted));
      },
    );
  }
}
