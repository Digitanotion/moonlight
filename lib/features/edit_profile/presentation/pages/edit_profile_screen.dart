import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/widgets/moon_snack.dart';
import '../cubit/edit_profile_cubit.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _fullname = TextEditingController();
  final _bio = TextEditingController();
  final _phone = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    context.read<EditProfileCubit>().load();
  }

  @override
  void dispose() {
    _fullname.dispose();
    _bio.dispose();
    _phone.dispose();
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

    return BlocConsumer<EditProfileCubit, EditProfileState>(
      listener: (context, state) {
        if (state.success) {
          MoonSnack.success(context, "Profile updated");
        } else if (state.error != null) {
          MoonSnack.error(context, state.error!);
        }
      },
      builder: (context, state) {
        // keep controllers synced with state when first loaded
        if (!state.loading &&
            _fullname.text.isEmpty &&
            state.fullname.isNotEmpty) {
          _fullname.text = state.fullname;
          _bio.text = state.bio ?? '';
          _phone.text = state.phone ?? '';
        }

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(gradient: gradient),
            child: SafeArea(
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            'Edit Profile',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Update how others see you",
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 20),

                          // Avatar (current OR new)
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.08),
                                        border: Border.all(
                                          color: Colors.white24,
                                          width: 1,
                                        ),
                                        image: state.avatarPath != null
                                            ? DecorationImage(
                                                image: FileImage(
                                                  File(state.avatarPath!),
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : (state.avatarUrl != null
                                                  ? DecorationImage(
                                                      image: NetworkImage(
                                                        state.avatarUrl!,
                                                      ),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null),
                                      ),
                                      alignment: Alignment.center,
                                      child:
                                          (state.avatarUrl == null &&
                                              state.avatarPath == null)
                                          ? const Icon(
                                              Icons.person_outline,
                                              color: Colors.white70,
                                              size: 30,
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      right: -6,
                                      bottom: -6,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white70,
                                        ),
                                        onPressed: () async {
                                          final x = await _picker.pickImage(
                                            source: ImageSource.gallery,
                                            imageQuality: 85,
                                          );
                                          if (x != null)
                                            context
                                                .read<EditProfileCubit>()
                                                .setAvatarPath(x.path);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () => context
                                      .read<EditProfileCubit>()
                                      .markRemoveAvatar(),
                                  child: const Text(
                                    'Remove photo',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          _Input(
                            label: 'Full Name',
                            hint: 'Enter your full name',
                            controller: _fullname,
                            onChanged: (v) =>
                                context.read<EditProfileCubit>().setFullname(v),
                          ),
                          const SizedBox(height: 14),

                          // Country dropdown
                          _Dropdown(
                            label: 'Country',
                            hint: 'Select your country',
                            value: state.country,
                            items: state.countries,
                            onChanged: (v) =>
                                context.read<EditProfileCubit>().setCountry(v),
                          ),
                          const SizedBox(height: 14),

                          Text(
                            'Gender',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              _RadioChip(
                                'male',
                                'Male',
                                state.gender,
                                (v) => context
                                    .read<EditProfileCubit>()
                                    .setGender(v),
                              ),
                              _RadioChip(
                                'female',
                                'Female',
                                state.gender,
                                (v) => context
                                    .read<EditProfileCubit>()
                                    .setGender(v),
                              ),
                              _RadioChip(
                                'other',
                                'Other',
                                state.gender,
                                (v) => context
                                    .read<EditProfileCubit>()
                                    .setGender(v),
                              ),
                              _RadioChip(
                                'prefer_not_to_say',
                                'Prefer not to say',
                                state.gender,
                                (v) => context
                                    .read<EditProfileCubit>()
                                    .setGender(v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          _Input(
                            label: 'Short Bio',
                            hint: 'Tell people a little about you...',
                            controller: _bio,
                            maxLines: 4,
                            onChanged: (v) =>
                                context.read<EditProfileCubit>().setBio(v),
                          ),
                          const SizedBox(height: 14),

                          _Input(
                            label: 'Phone (optional)',
                            hint: '+234...',
                            controller: _phone,
                            onChanged: (v) =>
                                context.read<EditProfileCubit>().setPhone(v),
                          ),
                          const SizedBox(height: 22),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: state.submitting
                                  ? null
                                  : () => context
                                        .read<EditProfileCubit>()
                                        .submit(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: orange,
                                disabledBackgroundColor: orange.withOpacity(
                                  0.5,
                                ),
                                foregroundColor: Colors.black,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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
                                      'Save Changes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                RouteNames.home,
                              ),
                              child: const Text(
                                'Cancel',
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
}

class _Input extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _Input({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
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
  final ValueChanged<String?> onChanged;
  const _Dropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
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
              items: items
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
              onChanged: onChanged,
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
  final String value;
  final String title;
  final String? group;
  final ValueChanged<String> onChanged;
  const _RadioChip(
    this.value,
    this.title,
    this.group,
    this.onChanged, {
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    final selected = value == group;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFFF7A00) : const Color(0x29FFFFFF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? const Color(0xFFFF7A00) : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
