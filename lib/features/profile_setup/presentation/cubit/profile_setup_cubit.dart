import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/core/network/error_parser.dart';
import '../../../profile_setup/domain/usecases/setup_profile.dart';
import '../../../profile_setup/domain/repositories/profile_repository.dart';

part 'profile_setup_state.dart';

class ProfileSetupCubit extends Cubit<ProfileSetupState> {
  final SetupProfile setupProfile;
  final ProfileRepository repo;
  ProfileSetupCubit(this.setupProfile, this.repo)
    : super(ProfileSetupState.initial());

  Future<void> loadCountries() async {
    try {
      emit(state.copyWith(loadingCountries: true));
      final list = await repo.getCountries();
      emit(state.copyWith(loadingCountries: false, countries: list));
    } catch (_) {
      emit(state.copyWith(loadingCountries: false, countries: const []));
    }
  }

  void setAvatarPath(String? path) => emit(state.copyWith(avatarPath: path));
  void setGender(String? g) => emit(state.copyWith(gender: g));
  void setCountry(String? c) => emit(state.copyWith(country: c));
  void setFullname(String v) => emit(state.copyWith(fullname: v));
  void setBio(String v) => emit(state.copyWith(bio: v));
  void setPhone(String v) => emit(state.copyWith(phone: v));
  void setDob(DateTime? v) => emit(state.copyWith(dob: v)); // UI-only

  Future<void> submit({List<String>? interests}) async {
    if (state.fullname.trim().isEmpty) {
      emit(state.copyWith(error: 'Full name is required'));
      return;
    }
    emit(state.copyWith(submitting: true, error: null));
    try {
      await setupProfile(
        fullname: state.fullname.trim(),
        gender: state.gender,
        country: state.country,
        bio: state.bio?.trim().isEmpty == true ? null : state.bio?.trim(),
        interests: interests,
        phone: state.phone?.trim().isEmpty == true ? null : state.phone?.trim(),
        avatarPath: state.avatarPath,
      );
      emit(state.copyWith(submitting: false, success: true));
    } catch (e) {
      emit(state.copyWith(submitting: false, error: apiErrorMessage(e)));
    }
  }
}
