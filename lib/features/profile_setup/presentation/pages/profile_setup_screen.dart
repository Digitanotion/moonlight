import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_button.dart';
import 'package:moonlight/features/profile_setup/presentation/bloc/profile_setup_bloc.dart';
import 'package:moonlight/features/profile_setup/presentation/widgets/date_picker_field.dart';
import 'package:moonlight/features/profile_setup/presentation/widgets/dropdown_field.dart';
import 'package:moonlight/features/profile_setup/presentation/widgets/gender_selector.dart';
import 'package:moonlight/features/profile_setup/presentation/widgets/profile_text_field.dart';
import 'package:moonlight/features/profile_setup/presentation/widgets/profile_avatar.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _bioController;
  late ProfileSetupBloc _bloc;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc = BlocProvider.of<ProfileSetupBloc>(context);
    _bloc.add(LoadCountries());
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileSetupBloc, ProfileSetupState>(
      listener: (context, state) {
        if (state.status == ProfileSetupStatus.success) {
          Navigator.pushReplacementNamed(context, RouteNames.home);
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.dark],
                begin: Alignment.topLeft,
                end: Alignment.topRight,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Set Up Your Profile',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textWhite,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Personalize your space so others can discover and connect with you',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Profile Avatar Section
                    Center(
                      child: ProfileAvatar(
                        initialImageUrl: state.profile.profileImageUrl,
                        onImageSelected: (imageFile) {
                          if (imageFile != null) {
                            _bloc.add(ProfileImageChanged(imageFile));
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Divider(color: AppColors.textSecondary),
                    const SizedBox(height: 24),

                    ProfileTextField(
                      label: 'Full Name',
                      hintText: 'Enter your full name',
                      controller: _fullNameController,
                      onChanged: (value) => _bloc.add(FullNameChanged(value)),
                    ),
                    DatePickerField(
                      label: 'Date of Birth',
                      selectedDate: state.profile.dateOfBirth,
                      onDateSelected: (date) =>
                          _bloc.add(DateOfBirthChanged(date)),
                    ),
                    DropdownField(
                      label: 'Country',
                      value: state.profile.country,
                      items: state.countries,
                      onChanged: (value) => _bloc.add(CountryChanged(value!)),
                      hintText: 'Select your country',
                    ),
                    GenderSelector(
                      selectedGender: state.profile.gender,
                      onGenderSelected: (gender) =>
                          _bloc.add(GenderChanged(gender)),
                    ),
                    ProfileTextField(
                      label: 'Short Bio',
                      hintText: 'Tell people a little about you...',
                      maxLines: 3,
                      controller: _bioController,
                      onChanged: (value) => _bloc.add(BioChanged(value)),
                    ),
                    const SizedBox(height: 32),
                    if (state.status == ProfileSetupStatus.loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      AuthButton(
                        text: 'Update Profile',
                        onPressed: () => _bloc.add(SubmitProfile()),
                      ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(
                            context,
                            RouteNames.home,
                          );
                        },
                        child: Text(
                          'Skip for now',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
