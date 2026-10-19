import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/presentation/club_coins_ui.dart';
import 'create_club_state.dart';

class CreateClubCubit extends Cubit<CreateClubState> {
  final ClubsRepository repository;

  CreateClubCubit(this.repository) : super(const CreateClubState());

  // ---- setters ----
  void setName(String v) => emit(state.copyWith(name: v));
  void setDescription(String v) => emit(state.copyWith(description: v));
  void setMotto(String v) => emit(state.copyWith(motto: v));
  void setLocation(String v) => emit(state.copyWith(location: v));
  void togglePrivate(bool v) => emit(state.copyWith(isPrivate: v));
  void setCoverImage(File file) => emit(state.copyWith(coverImageFile: file));

  // ---- submit ----
  Future<void> submit() async {
    if (state.name.trim().isEmpty) {
      emit(state.copyWith(errorMessage: 'Club name is required'));
      return;
    }

    try {
      emit(state.copyWith(loading: true, errorMessage: null));

      final club = await repository.createClubMultipart(
        name: state.name.trim(),
        description: state.description,
        motto: state.motto,
        location: state.location,
        isPrivate: state.isPrivate,
        coverImage: state.coverImageFile,
      );

      emit(state.copyWith(loading: false, createdClub: club));
    } catch (e) {
      debugPrint(e.toString());
      emit(
        state.copyWith(
          loading: false,
          // e.g. 402 "Creating a club costs 100 coins. Top up your wallet…"
          errorMessage: clubApiMessage(
            e,
            'Failed to create club. Please try again.',
          ),
        ),
      );
    }
  }

  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }
}
