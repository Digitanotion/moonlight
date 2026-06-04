// lib/features/clubs/presentation/cubit/club_treasury_cubit.dart
//
// CHANGE: submitRequest() now safely unwraps the full response body
// {status, message, data: {...}} returned by the fixed data source.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/club_treasury.dart';
import '../../data/datasources/club_treasury_remote_data_source.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class ClubTreasuryState extends Equatable {
  final bool loading;
  final bool submitting;
  final bool verifyingPin;
  final ClubTreasurySummary? summary;
  final List<ClubWithdrawalRequest> requests;
  final String? error;
  final String? success;
  final bool pinVerified;

  const ClubTreasuryState({
    this.loading = false,
    this.submitting = false,
    this.verifyingPin = false,
    this.summary,
    this.requests = const [],
    this.error,
    this.success,
    this.pinVerified = false,
  });

  ClubTreasuryState copyWith({
    bool? loading,
    bool? submitting,
    bool? verifyingPin,
    ClubTreasurySummary? summary,
    List<ClubWithdrawalRequest>? requests,
    String? error,
    String? success,
    bool? pinVerified,
  }) {
    return ClubTreasuryState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      verifyingPin: verifyingPin ?? this.verifyingPin,
      summary: summary ?? this.summary,
      requests: requests ?? this.requests,
      error: error ?? this.error,
      success: success ?? this.success,
      pinVerified: pinVerified ?? this.pinVerified,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    submitting,
    summary,
    requests,
    error,
    success,
    pinVerified,
  ];
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class ClubTreasuryCubit extends Cubit<ClubTreasuryState> {
  final ClubTreasuryRemoteDataSource _ds;
  final String clubUuid;

  ClubTreasuryCubit(this._ds, this.clubUuid) : super(const ClubTreasuryState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final summaryData = await _ds.getSummary(clubUuid);
      final requestsData = await _ds.getWithdrawalRequests(clubUuid);
      emit(
        state.copyWith(
          loading: false,
          summary: ClubTreasurySummary.fromJson(summaryData),
          requests: requestsData
              .map((r) => ClubWithdrawalRequest.fromJson(r))
              .toList(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _clean(e)));
    }
  }

  Future<void> loadRequests({String? status}) async {
    try {
      final data = await _ds.getWithdrawalRequests(clubUuid, status: status);
      emit(
        state.copyWith(
          requests: data.map((r) => ClubWithdrawalRequest.fromJson(r)).toList(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: _clean(e)));
    }
  }

  Future<bool> verifyPin(String pin) async {
    emit(state.copyWith(verifyingPin: true, error: null));
    final ok = await _ds.verifyPin(clubUuid, pin);
    emit(
      state.copyWith(
        verifyingPin: false,
        pinVerified: ok,
        error: ok ? null : 'Incorrect treasury PIN.',
      ),
    );
    return ok;
  }

  Future<void> setPin(String newPin, {String? currentPin}) async {
    emit(state.copyWith(submitting: true, error: null));
    try {
      await _ds.setPin(clubUuid, newPin, currentPin: currentPin);
      emit(
        state.copyWith(
          submitting: false,
          success: 'Treasury PIN saved successfully.',
        ),
      );
      await load();
    } catch (e) {
      emit(state.copyWith(submitting: false, error: _clean(e)));
    }
  }

  Future<void> updatePolicy(Map<String, dynamic> policy) async {
    emit(state.copyWith(submitting: true, error: null));
    try {
      await _ds.updatePolicy(clubUuid, policy);
      emit(state.copyWith(submitting: false, success: 'Policy updated.'));
      await load();
    } catch (e) {
      emit(state.copyWith(submitting: false, error: _clean(e)));
    }
  }

  Future<void> updatePayoutProfile(Map<String, dynamic> data) async {
    emit(state.copyWith(submitting: true, error: null));
    try {
      await _ds.updatePayoutProfile(clubUuid, data);
      emit(
        state.copyWith(submitting: false, success: 'Payout profile updated.'),
      );
      await load();
    } catch (e) {
      emit(state.copyWith(submitting: false, error: _clean(e)));
    }
  }

  Future<ClubWithdrawalRequest?> submitRequest(
    Map<String, dynamic> data,
  ) async {
    emit(state.copyWith(submitting: true, error: null, success: null));
    try {
      // Data source now returns the FULL body: {status, message, data: {...}}
      final body = await _ds.submitWithdrawalRequest(clubUuid, data);

      // Extract message from top-level (never null — has fallback)
      final message =
          body['message'] as String? ?? 'Withdrawal submitted successfully.';

      // Extract the nested request object safely
      final requestJson = body['data'];
      if (requestJson == null) {
        // Submitted OK but no data object — still treat as success
        emit(state.copyWith(submitting: false, success: message));
        await load();
        return null;
      }

      final request = ClubWithdrawalRequest.fromJson(
        Map<String, dynamic>.from(requestJson as Map),
      );

      emit(
        state.copyWith(
          submitting: false,
          success: message,
          requests: [request, ...state.requests],
        ),
      );
      await load();
      return request;
    } catch (e) {
      emit(state.copyWith(submitting: false, error: _clean(e)));
      return null;
    }
  }

  Future<void> approveRequest(
    String requestUuid,
    String pin, {
    String? note,
  }) async {
    emit(state.copyWith(submitting: true, error: null));
    try {
      final res = await _ds.approveRequest(
        clubUuid,
        requestUuid,
        pin,
        note: note,
      );
      final updated = ClubWithdrawalRequest.fromJson(res);
      _updateRequestInList(updated);
      emit(
        state.copyWith(
          submitting: false,
          success: updated.quorumReached
              ? 'Approved! Withdrawal is now processing.'
              : 'Vote recorded.',
        ),
      );
      await load();
    } catch (e) {
      emit(state.copyWith(submitting: false, error: _clean(e)));
    }
  }

  Future<void> rejectRequest(String requestUuid, String note) async {
    emit(state.copyWith(submitting: true, error: null));
    try {
      final res = await _ds.rejectRequest(clubUuid, requestUuid, note);
      final updated = ClubWithdrawalRequest.fromJson(res);
      _updateRequestInList(updated);
      emit(state.copyWith(submitting: false, success: 'Request rejected.'));
    } catch (e) {
      emit(state.copyWith(submitting: false, error: _clean(e)));
    }
  }

  Future<void> cancelRequest(String requestUuid, String pin) async {
    emit(state.copyWith(submitting: true, error: null));
    try {
      await _ds.cancelRequest(clubUuid, requestUuid, pin);
      emit(
        state.copyWith(
          submitting: false,
          success: 'Request cancelled.',
          requests: state.requests.where((r) => r.uuid != requestUuid).toList(),
        ),
      );
      await load();
    } catch (e) {
      emit(state.copyWith(submitting: false, error: _clean(e)));
    }
  }

  void clearMessages() => emit(state.copyWith(error: null, success: null));

  void _updateRequestInList(ClubWithdrawalRequest updated) {
    final list = state.requests
        .map((r) => r.uuid == updated.uuid ? updated : r)
        .toList();
    emit(state.copyWith(requests: list));
  }

  String _clean(Object e) {
    final s = e.toString();
    if (s.contains('"message"')) {
      final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(s);
      if (match != null) return match.group(1)!;
    }
    return s.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }
}
