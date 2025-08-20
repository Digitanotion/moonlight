part of 'profile_setup_bloc.dart';

abstract class ProfileSetupEvent extends Equatable {
  const ProfileSetupEvent();

  @override
  List<Object> get props => [];
}

class LoadCountries extends ProfileSetupEvent {}

class FullNameChanged extends ProfileSetupEvent {
  final String fullName;

  const FullNameChanged(this.fullName);

  @override
  List<Object> get props => [fullName];
}

class DateOfBirthChanged extends ProfileSetupEvent {
  final DateTime dateOfBirth;

  const DateOfBirthChanged(this.dateOfBirth);

  @override
  List<Object> get props => [dateOfBirth];
}

class CountryChanged extends ProfileSetupEvent {
  final String country;

  const CountryChanged(this.country);

  @override
  List<Object> get props => [country];
}

class GenderChanged extends ProfileSetupEvent {
  final Gender gender;

  const GenderChanged(this.gender);

  @override
  List<Object> get props => [gender];
}

class BioChanged extends ProfileSetupEvent {
  final String bio;

  const BioChanged(this.bio);

  @override
  List<Object> get props => [bio];
}

class SubmitProfile extends ProfileSetupEvent {}

class SkipProfileSetup extends ProfileSetupEvent {}

// Add this event to the existing events
class ProfileImageChanged extends ProfileSetupEvent {
  final File profileImage;

  const ProfileImageChanged(this.profileImage);

  @override
  List<Object> get props => [profileImage];
}
