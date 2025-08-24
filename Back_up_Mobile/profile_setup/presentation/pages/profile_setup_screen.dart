// lib/features/profile/presentation/pages/profile_setup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/utils/countries.dart';
import '../../domain/profile_repository.dart';
import '../cubit/profile_setup_cubit.dart';
import '../cubit/profile_setup_state.dart';
import '../utils/countries.dart';
import '../utils/interests.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key, this.isUpdate = false});
  final bool isUpdate; // false => initial setup; true => edit profile

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileSetupCubit(sl<ProfileRepository>()),
      child: const _ProfileSetupView(),
    );
  }
}

class _ProfileSetupView extends StatefulWidget {
  const _ProfileSetupView();

  @override
  State<_ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<_ProfileSetupView> {
  final _formKey = GlobalKey<FormState>();
  final _fullnameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  get kInterestCatalog => null;

  @override
  void dispose() {
    _fullnameCtrl.dispose();
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (img != null) {
      context.read<ProfileSetupCubit>().setAvatarPath(img.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProfileSetupCubit>();

    return BlocConsumer<ProfileSetupCubit, ProfileSetupState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
        if (!state.loading && state.profile != null) {
          // Success → navigate to Home/Profile
          Navigator.of(context).pop(state.profile);
        }
      },
      builder: (context, state) {
        final avatar = state.avatarPath == null
            ? null
            : File(state.avatarPath!);

        return Scaffold(
          appBar: AppBar(title: const Text('Profile Setup')),
          body: AbsorbPointer(
            absorbing: state.loading,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundImage: avatar != null
                                ? FileImage(avatar)
                                : null,
                            child: avatar == null
                                ? const Icon(Icons.person, size: 48)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () => _pickAvatar(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blueAccent,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fullname
                    TextFormField(
                      controller: _fullnameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full name *',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: cubit.setFullname,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Full name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Gender
                    DropdownButtonFormField<String>(
                      value: state.gender,
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                        DropdownMenuItem(
                          value: 'prefer_not_to_say',
                          child: Text('Prefer not to say'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: cubit.setGender,
                    ),
                    const SizedBox(height: 12),

                    // Country
                    DropdownButtonFormField<String>(
                      value: state.country,
                      items: kCountries
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: cubit.setCountry,
                    ),
                    const SizedBox(height: 12),

                    // Phone
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: cubit.setPhone,
                    ),
                    const SizedBox(height: 12),

                    // Bio
                    TextFormField(
                      controller: _bioCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: cubit.setBio,
                    ),
                    const SizedBox(height: 16),

                    // Interests multi-select
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Interests',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final it in kInterestCatalog)
                          FilterChip(
                            label: Text(it),
                            selected: state.interests.contains(it),
                            onSelected: (_) => cubit.toggleInterest(it),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: state.loading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  cubit.submitInitial();
                                }
                              },
                        child: state.loading
                            ? const CircularProgressIndicator.adaptive()
                            : const Text('Save & Continue'),
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
