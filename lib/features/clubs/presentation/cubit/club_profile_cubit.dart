import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/domain/entities/club_profile.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'club_profile_state.dart';

class ClubProfileCubit extends Cubit<ClubProfileState> {
  final ClubsRepository repository;

  ClubProfileCubit(this.repository)
    : super(const ClubProfileState(loading: true));

  Future<void> load(String clubUuid) async {
    try {
      emit(state.copyWith(loading: true, error: null, success: null));
      final profile = await repository.getClubProfile(clubUuid);
      emit(state.copyWith(loading: false, profile: profile));
    } catch (e, stack) {
      debugPrint('❌ ClubProfileCubit.load error: $e\n$stack'); // ← add this
      emit(
        state.copyWith(loading: false, error: 'Failed to load club profile'),
      );
    }
  }

  Future<void> joinClub() async {
    final p = state.profile;
    if (state.joining || p == null || p.isMember) return;

    emit(_working());

    try {
      await repository.joinClub(p.uuid);
      emit(
        _idle(
          profile: p.copyWith(isMember: true, membersCount: p.membersCount + 1),
          success: '🎉 Successfully joined the club!',
        ),
      );
    } on DioException catch (e) {
      // A failing post-commit notification used to 500 an otherwise
      // successful join — verify before showing an error.
      if ((e.response?.statusCode ?? 0) >= 500 ||
          e.response?.statusCode == null) {
        await _verifyMembership(p, shouldBeMember: true);
      } else if (e.response?.statusCode == 409) {
        emit(_idle(profile: p.copyWith(isMember: true)));
      } else {
        emit(_idle(error: 'Failed to join club'));
      }
    } catch (_) {
      emit(_idle(error: 'Failed to join club'));
    }
  }

  Future<void> leaveClub() async {
    final p = state.profile;
    // The owner can't leave (must transfer / delete first).
    if (state.joining || p == null || !p.isMember || p.isCreator) return;

    emit(_working());

    try {
      await repository.leaveClub(p.uuid);
      emit(
        _idle(
          profile: p.copyWith(
            isMember: false,
            isAdmin: false,
            membersCount: (p.membersCount - 1) < 0 ? 0 : p.membersCount - 1,
          ),
          success: 'You left the club',
        ),
      );
    } on DioException catch (e) {
      if ((e.response?.statusCode ?? 0) >= 500 ||
          e.response?.statusCode == null) {
        await _verifyMembership(p, shouldBeMember: false);
      } else if (e.response?.statusCode == 409) {
        // "Not a member" — already out.
        emit(_idle(profile: p.copyWith(isMember: false)));
      } else {
        emit(_idle(error: 'Failed to leave club'));
      }
    } catch (_) {
      emit(_idle(error: 'Failed to leave club'));
    }
  }

  Future<void> _verifyMembership(
    ClubProfile p, {
    required bool shouldBeMember,
  }) async {
    try {
      final fresh = await repository.getClubProfile(p.uuid);
      if (fresh.isMember == shouldBeMember) {
        emit(
          _idle(
            profile: fresh,
            success: shouldBeMember
                ? '🎉 Successfully joined the club!'
                : 'You left the club',
          ),
        );
        return;
      }
      emit(_idle(profile: fresh));
    } catch (_) {
      emit(
        _idle(
          error: shouldBeMember
              ? 'Failed to join club'
              : 'Failed to leave club',
        ),
      );
    }
  }

  void clearMessages() => emit(_idle());

  // `ClubProfileState.copyWith` can't set error/success back to null, so build
  // the message-free states explicitly.
  ClubProfileState _working() => ClubProfileState(
    loading: state.loading,
    joining: true,
    profile: state.profile,
  );

  ClubProfileState _idle({
    ClubProfile? profile,
    String? error,
    String? success,
  }) => ClubProfileState(
    loading: state.loading,
    joining: false,
    profile: profile ?? state.profile,
    error: error,
    success: success,
  );
}
