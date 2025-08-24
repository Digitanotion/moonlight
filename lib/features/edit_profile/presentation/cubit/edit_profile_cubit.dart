import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/profile_setup/domain/repositories/profile_repository.dart';
import 'package:moonlight/features/profile_setup/domain/usecases/update_profile.dart';
import 'package:moonlight/features/profile_setup/domain/repositories/profile_repository.dart'
    as repo;
import 'package:moonlight/features/auth/domain/usecases/get_current_user.dart';
import 'package:moonlight/features/auth/data/models/user_model.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';

part 'edit_profile_state.dart';

class EditProfileCubit extends Cubit<EditProfileState> {
  final GetCurrentUser getCurrentUser; // to prefill
  final repo.ProfileRepository profileRepo; // for countries (reuse)
  final UpdateProfile updateProfile; // update call
  final AuthLocalDataSource authLocal; // to cache updated user

  EditProfileCubit({
    required this.getCurrentUser,
    required this.profileRepo,
    required this.updateProfile,
    required this.authLocal,
  }) : super(EditProfileState.initial());

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));

    try {
      final userEither = await getCurrentUser();
      userEither.fold(
        (fail) => emit(state.copyWith(loading: false, error: fail.message)),
        (user) async {
          final countries = await profileRepo.getCountries();
          emit(
            state.copyWith(
              loading: false,
              countries: countries,
              fullname: user.fullname ?? '',
              gender: user.gender,
              country: user.country,
              bio: user.bio,
              phone: user.phone,
              avatarUrl: user.avatarUrl,
            ),
          );
        },
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  // setters
  void setFullname(String v) => emit(state.copyWith(fullname: v));
  void setGender(String? v) => emit(state.copyWith(gender: v));
  void setCountry(String? v) => emit(state.copyWith(country: v));
  void setBio(String v) => emit(state.copyWith(bio: v));
  void setPhone(String v) => emit(state.copyWith(phone: v));
  void setAvatarPath(String? p) =>
      emit(state.copyWith(avatarPath: p, removeAvatar: false));
  void markRemoveAvatar() =>
      emit(state.copyWith(avatarPath: null, removeAvatar: true));

  Future<void> submit() async {
    if (state.submitting) return;
    if (state.fullname.trim().isEmpty) {
      emit(state.copyWith(error: 'Full name is required'));
      return;
    }

    emit(state.copyWith(submitting: true, error: null));
    try {
      final updatedUserMap = await updateProfile(
        fullname: state.fullname.trim(),
        gender: state.gender,
        country: state.country,
        bio: state.bio?.trim().isEmpty == true ? null : state.bio?.trim(),
        phone: state.phone?.trim().isEmpty == true ? null : state.phone?.trim(),
        avatarPath: state.avatarPath,
        removeAvatar: state.removeAvatar,
      );

      // Persist updated user locally so all screens reflect changes
      try {
        final updated = UserModel.fromJson(updatedUserMap);
        await authLocal.cacheUser(updated);
      } catch (_) {
        /* if shape differs, skip caching silently */
      }

      emit(state.copyWith(submitting: false, success: true));
    } catch (e) {
      emit(state.copyWith(submitting: false, error: e.toString()));
    }
  }
}
