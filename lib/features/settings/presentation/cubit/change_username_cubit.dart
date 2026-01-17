import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/features/settings/domain/repositories/change_username_repository.dart';

part 'change_username_state.dart';

class ChangeUsernameCubit extends Cubit<ChangeUsernameState> {
  final ChangeUsernameRepository _repository;
  Timer? _cooldownTimer;

  ChangeUsernameCubit(this._repository) : super(const ChangeUsernameState()) {
    _startCooldownTimer();
  }

  void _startCooldownTimer() {
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.lastUsernameChange != null && !state.canChangeUsername) {
        emit(state.copyWith());
      }
    });
  }

  Future<void> loadCurrentUsername() async {
    try {
      final result = await _repository.getUsernameHistory(page: 1, perPage: 1);

      // 'data' is a List, not a Map
      final dataList = List<Map<String, dynamic>>.from(result['data'] ?? []);

      if (dataList.isNotEmpty) {
        final current = dataList.first;
        final oldUsername = current['old_username']?.toString();
        final newUsername = current['new_username']?.toString();
        final lastChange = current['changed_at']?.toString();

        DateTime? lastChangeDate;
        if (lastChange != null) {
          lastChangeDate = DateTime.tryParse(lastChange);
        }

        emit(
          state.copyWith(
            currentUsername: newUsername, // Use new_username as current
            lastUsernameChange: lastChangeDate,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to load current username: $e');
      // Re-throw to see the actual error
      rethrow;
    }
  }

  Future<void> changeUsername({
    required String newUsername,
    required String password,
  }) async {
    if (!state.canChangeUsername) {
      emit(
        state.copyWith(
          status: ChangeUsernameStatus.error,
          error: state.cooldownMessage ?? 'Cannot change username yet',
        ),
      );
      return;
    }

    try {
      emit(state.copyWith(status: ChangeUsernameStatus.loading));

      final result = await _repository.changeUsername(
        username: newUsername.trim(),
        password: password,
      );

      final data = Map<String, dynamic>.from(result['data'] ?? {});
      final newUsernameFromResponse =
          data['new_username']?.toString() ?? newUsername;

      emit(
        ChangeUsernameState(
          status: ChangeUsernameStatus.success,
          currentUsername: newUsernameFromResponse,
          message:
              result['message']?.toString() ?? 'Username changed successfully',
          data: data,
          lastUsernameChange: DateTime.now(),
        ),
      );
    } catch (e) {
      String errorMessage = 'Failed to change username';
      if (e.toString().contains('password') ||
          e.toString().contains('incorrect')) {
        errorMessage = 'Incorrect password';
      } else if (e.toString().contains('taken') ||
          e.toString().contains('already')) {
        errorMessage = 'Username is already taken';
      } else if (e.toString().contains('cooldown') ||
          e.toString().contains('30 days')) {
        errorMessage = 'You can only change your username once every 30 days';
      }

      emit(
        state.copyWith(status: ChangeUsernameStatus.error, error: errorMessage),
      );
    }
  }

  Future<void> checkUsername(String username) async {
    if (username.length < 3) {
      emit(state.copyWith(isUsernameAvailable: null, suggestions: []));
      return;
    }

    // Don't check if it's the same as current username
    if (username == state.currentUsername) {
      emit(state.copyWith(isUsernameAvailable: true, suggestions: []));
      return;
    }

    try {
      emit(state.copyWith(status: ChangeUsernameStatus.checking));

      final result = await _repository.checkUsername(username.trim());
      final data = Map<String, dynamic>.from(result['data'] ?? {});

      emit(
        state.copyWith(
          status: ChangeUsernameStatus.initial,
          isUsernameAvailable: data['available'] as bool? ?? false,
          validationErrors: List<String>.from(data['validation_errors'] ?? []),
          suggestions: List<String>.from(data['suggestions'] ?? []),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ChangeUsernameStatus.initial,
          isUsernameAvailable: null,
          suggestions: [],
        ),
      );
      // Don't show error for check, just reset state
    }
  }

  void clearUsernameAvailability() {
    emit(state.copyWith(isUsernameAvailable: null, suggestions: []));
  }

  Future<void> loadUsernameHistory() async {
    try {
      final result = await _repository.getUsernameHistory();

      // 'data' is already a List in the response
      final dataList = List<Map<String, dynamic>>.from(result['data'] ?? []);

      emit(state.copyWith(usernameHistory: dataList));
    } catch (e) {
      debugPrint('Failed to load username history: $e');
      rethrow;
    }
  }

  void reset() {
    _cooldownTimer?.cancel();
    emit(const ChangeUsernameState());
    _startCooldownTimer();
  }

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }
}
