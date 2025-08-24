import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_setup_cubit.dart';
import 'package:moonlight/widgets/moon_snack.dart';
import 'package:shared_preferences/shared_preferences.dart'; // keep if you have it

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _bio = TextEditingController();
  final _fullname = TextEditingController();
  final _phone = TextEditingController();
  final _dobCtrl = TextEditingController(); // UI only

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    context.read<ProfileSetupCubit>().loadCountries();
  }

  @override
  void dispose() {
    _bio.dispose();
    _fullname.dispose();
    _phone.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    final gradient = const LinearGradient(
      colors: [Color(0xFF0C0F52), Color(0xFF0A0A0F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return BlocConsumer<ProfileSetupCubit, ProfileSetupState>(
      listener: (context, state) async {
        if (state.success) {
          // ✅ Persist onboarding completion for skip
          final prefs = await SharedPreferences.getInstance();

          await prefs.setBool('hasCompletedProfile', true);
          MoonSnack.success(context, "Great Job! Profile saved");
          Navigator.pushReplacementNamed(context, '/interests');
        } else if (state.error != null) {
          MoonSnack.error(context, state.error!);
          // ScaffoldMessenger.of(
          //   context,
          // ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(gradient: gradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      'Set Up Your Profile',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Personalize your space so others can discover and connect with you",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),

                    // avatar picker (circle + camera icon)
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final x = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (x != null) {
                            context.read<ProfileSetupCubit>().setAvatarPath(
                              x.path,
                            );
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.08),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: state.avatarPath == null
                                  ? const Icon(
                                      Icons.photo_camera_outlined,
                                      color: Colors.white70,
                                      size: 26,
                                    )
                                  : ClipOval(
                                      child: Image.file(
                                        File(state.avatarPath!),
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tap to upload a profile picture',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Full name
                    _Input(
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      controller: _fullname,
                      onChanged: (v) =>
                          context.read<ProfileSetupCubit>().setFullname(v),
                    ),
                    const SizedBox(height: 14),

                    // DOB (UI only)
                    _Input(
                      label: 'Date of Birth',
                      hint: 'mm/dd/yyyy',
                      controller: _dobCtrl,
                      readOnly: true,
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(
                            now.year - 18,
                            now.month,
                            now.day,
                          ),
                          firstDate: DateTime(1900),
                          lastDate: now,
                          helpText: 'Select Date of Birth',
                        );
                        if (picked != null) {
                          _dobCtrl.text =
                              "${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}";
                          context.read<ProfileSetupCubit>().setDob(picked);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Country dropdown
                    _Dropdown(
                      label: 'Country',
                      hint: 'Select your country',
                      value: state.country,
                      items: state.countries,
                      loading: state.loadingCountries,
                      onChanged: (v) =>
                          context.read<ProfileSetupCubit>().setCountry(v),
                    ),
                    const SizedBox(height: 14),

                    // Gender radios
                    Text('Gender', style: _labelStyle()),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _RadioChip(
                          title: 'Male',
                          value: 'male',
                          groupValue: state.gender,
                          onChanged: (v) =>
                              context.read<ProfileSetupCubit>().setGender(v),
                        ),
                        _RadioChip(
                          title: 'Female',
                          value: 'female',
                          groupValue: state.gender,
                          onChanged: (v) =>
                              context.read<ProfileSetupCubit>().setGender(v),
                        ),
                        _RadioChip(
                          title: 'Other',
                          value: 'other',
                          groupValue: state.gender,
                          onChanged: (v) =>
                              context.read<ProfileSetupCubit>().setGender(v),
                        ),
                        _RadioChip(
                          title: 'Prefer not to say',
                          value: 'prefer_not_to_say',
                          groupValue: state.gender,
                          onChanged: (v) =>
                              context.read<ProfileSetupCubit>().setGender(v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Short Bio
                    _Input(
                      label: 'Short Bio',
                      hint: 'Tell people a little about you...',
                      controller: _bio,
                      maxLines: 4,
                      onChanged: (v) =>
                          context.read<ProfileSetupCubit>().setBio(v),
                      helper:
                          'Tell people a little about you (max 140 characters)',
                    ),
                    const SizedBox(height: 6),

                    // Phone (optional)
                    _Input(
                      label: 'Phone (optional)',
                      hint: '+234...',
                      controller: _phone,
                      onChanged: (v) =>
                          context.read<ProfileSetupCubit>().setPhone(v),
                    ),
                    const SizedBox(height: 22),

                    // Update Profile button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state.submitting
                            ? null
                            : () => context.read<ProfileSetupCubit>().submit(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orange,
                          disabledBackgroundColor: orange.withOpacity(0.5),
                          foregroundColor: Colors.black,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: state.submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Update Profile',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          RouteNames.editProfile,
                        ),
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(color: Color(0xFF19D85E)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TextStyle _labelStyle() =>
      const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600);
}

class _Input extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback? onTap;
  final bool readOnly;
  final int maxLines;
  final String? helper;
  final ValueChanged<String>? onChanged;

  const _Input({
    required this.label,
    required this.hint,
    required this.controller,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.helper,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onTap: onTap,
          readOnly: readOnly,
          onChanged: onChanged,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: _border(),
            enabledBorder: _border(),
            focusedBorder: _border(color: Colors.white30),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            helperText: helper,
            helperStyle: const TextStyle(color: Colors.white38),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border({Color color = const Color(0x29FFFFFF)}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: 1),
      );
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final bool loading;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    super.key,
    required this.label,
    required this.hint,
    this.value,
    required this.items,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x29FFFFFF)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF151626),
              hint: Text(hint, style: const TextStyle(color: Colors.white54)),
              items: (loading ? <String>[] : items)
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: loading ? null : onChanged,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RadioChip extends StatelessWidget {
  final String title;
  final String value;
  final String? groupValue;
  final ValueChanged<String> onChanged;

  const _RadioChip({
    super.key,
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF7A00)
                : const Color(0x29FFFFFF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected ? const Color(0xFFFF7A00) : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
