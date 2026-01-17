import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/domain/entities/club_profile.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'edit_club_state.dart';

class EditClubCubit extends Cubit<EditClubState> {
  final ClubsRepository repository;
  final String clubUuid;

  EditClubCubit({required this.repository, required this.clubUuid})
    : super(const EditClubState());

  /* ───────── LOAD ───────── */

  Future<void> load() async {
    try {
      emit(state.copyWith(loading: true));

      final club = await repository.getClubProfile(clubUuid);

      emit(
        state.copyWith(
          loading: false,
          name: club.name,
          description: club.description,
          location: club.location,
          motto: club.motto,
          isPrivate: club.isPrivate, // baseline value
          existingCoverUrl: club.coverImageUrl,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Failed to load club information',
        ),
      );
    }
  }

  /* ───────── SETTERS ───────── */

  void setName(String v) => emit(state.copyWith(name: v));
  void setDescription(String v) => emit(state.copyWith(description: v));
  void setLocation(String v) => emit(state.copyWith(location: v));
  void setMotto(String v) => emit(state.copyWith(motto: v));

  void togglePrivate(bool v) => emit(state.copyWith(isPrivate: v));

  void setCoverImage(File file) => emit(state.copyWith(newCoverImage: file));

  /* ───────── SUBMIT ───────── */

  Future<void> submit() async {
    debugPrint('🔥 SUBMIT ENTERED');
    debugPrint('STATE BEFORE SUBMIT: $state');
    print('🔥 SUBMIT ENTERED');
    print('STATE BEFORE SUBMIT: $state');
    if (state.name.trim().isEmpty) {
      emit(state.copyWith(errorMessage: 'Club name is required'));
      return;
    }

    try {
      emit(state.copyWith(loading: true, errorMessage: null));
      debugPrint('🚀 CALLING updateClubMultipart');

      final updatedClub = await repository.updateClubMultipart(
        club: clubUuid,
        name: state.name.trim(),
        description: state.description?.trim().isEmpty == true
            ? null
            : state.description,
        motto: state.motto?.trim().isEmpty == true ? null : state.motto,
        location: state.location?.trim().isEmpty == true
            ? null
            : state.location,
        isPrivate: state.isPrivate,
        coverImage: state.newCoverImage,
      );

      debugPrint('✅ API RETURNED: ${updatedClub.uuid}');
      print('✅ API RETURNED: ${updatedClub.uuid}');

      emit(state.copyWith(loading: false, updatedClub: updatedClub));
    } catch (e) {
      debugPrint('❌ UPDATE FAILED');
      debugPrint(e.toString());
      print(e.toString());
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Failed to update club. Please try again.',
        ),
      );
    }
  }

  void clearError() => emit(state.copyWith(errorMessage: null));
}
