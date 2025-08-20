import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/profile_setup/domain/entities/user_profile.dart';
import 'package:moonlight/features/profile_setup/domain/usecases/get_countries.dart';
import 'package:moonlight/features/profile_setup/domain/usecases/update_profile.dart';

part 'profile_setup_event.dart';
part 'profile_setup_state.dart';

class ProfileSetupBloc extends Bloc<ProfileSetupEvent, ProfileSetupState> {
  final GetCountries getCountries;
  final UpdateProfile updateProfile;

  ProfileSetupBloc({required this.getCountries, required this.updateProfile})
    : super(ProfileSetupState(profile: const UserProfile(fullName: ''))) {
    on<LoadCountries>(_onLoadCountries);
    on<FullNameChanged>(_onFullNameChanged);
    on<DateOfBirthChanged>(_onDateOfBirthChanged);
    on<CountryChanged>(_onCountryChanged);
    on<GenderChanged>(_onGenderChanged);
    on<BioChanged>(_onBioChanged);
    on<SubmitProfile>(_onSubmitProfile);
    on<ProfileImageChanged>(_onProfileImageChanged);
  }

  Future<void> _onLoadCountries(
    LoadCountries event,
    Emitter<ProfileSetupState> emit,
  ) async {
    final result = await getCountries();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProfileSetupStatus.failure,
          errorMessage: 'Failed to load countries',
        ),
      ),
      (countries) => emit(state.copyWith(countries: countries)),
    );
  }

  void _onFullNameChanged(
    FullNameChanged event,
    Emitter<ProfileSetupState> emit,
  ) {
    emit(
      state.copyWith(profile: state.profile.copyWith(fullName: event.fullName)),
    );
  }

  void _onDateOfBirthChanged(
    DateOfBirthChanged event,
    Emitter<ProfileSetupState> emit,
  ) {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(dateOfBirth: event.dateOfBirth),
      ),
    );
  }

  void _onCountryChanged(
    CountryChanged event,
    Emitter<ProfileSetupState> emit,
  ) {
    emit(
      state.copyWith(profile: state.profile.copyWith(country: event.country)),
    );
  }

  void _onGenderChanged(GenderChanged event, Emitter<ProfileSetupState> emit) {
    emit(state.copyWith(profile: state.profile.copyWith(gender: event.gender)));
  }

  void _onBioChanged(BioChanged event, Emitter<ProfileSetupState> emit) {
    emit(state.copyWith(profile: state.profile.copyWith(bio: event.bio)));
  }

  void _onProfileImageChanged(
    ProfileImageChanged event,
    Emitter<ProfileSetupState> emit,
  ) {
    emit(
      state.copyWith(
        profile: state.profile.copyWith(profileImageFile: event.profileImage),
      ),
    );
  }

  // Register the handler in the constructor

  Future<void> _onSubmitProfile(
    SubmitProfile event,
    Emitter<ProfileSetupState> emit,
  ) async {
    if (state.profile.fullName.isEmpty) {
      emit(
        state.copyWith(
          status: ProfileSetupStatus.failure,
          errorMessage: 'Please enter your full name',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ProfileSetupStatus.loading));

    final result = await updateProfile(state.profile);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProfileSetupStatus.failure,
          errorMessage: 'Failed to update profile',
        ),
      ),
      (_) => emit(state.copyWith(status: ProfileSetupStatus.success)),
    );
  }
}
