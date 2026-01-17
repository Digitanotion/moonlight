import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_it/get_it.dart';

import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/presentation/cubit/create_club_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/create_club_state.dart';

class CreateClubScreen extends StatelessWidget {
  const CreateClubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<CreateClubCubit>(),
      child: const _CreateClubView(),
    );
  }
}

/* ───────────────────────────────────────────── */

class _CreateClubView extends StatefulWidget {
  const _CreateClubView();

  @override
  State<_CreateClubView> createState() => _CreateClubViewState();
}

class _CreateClubViewState extends State<_CreateClubView> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _motto = TextEditingController();

  final _picker = ImagePicker();

  Future<void> _pickImage(BuildContext context) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    context.read<CreateClubCubit>().setCoverImage(File(file.path));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateClubCubit, CreateClubState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.redAccent,
            ),
          );
          context.read<CreateClubCubit>().clearError();
        }

        if (state.createdClub != null) {
          Navigator.pushReplacementNamed(
            context,
            RouteNames.clubProfile,
            arguments: {'clubUuid': state.createdClub!.uuid},
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgBottom,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(context),
                  const SizedBox(height: 20),

                  _label('Club name'),
                  _input(
                    controller: _name,
                    hint: 'Enter club name',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),

                  _label('Description'),
                  _input(
                    controller: _description,
                    hint: 'What is this club about?',
                    maxLines: 4,
                  ),

                  _label('Location'),
                  _input(controller: _location, hint: 'City, Country'),

                  _label('Privacy'),
                  const SizedBox(height: 8),
                  _PrivacyToggle(),

                  _label('Cover image'),
                  const SizedBox(height: 8),
                  _ModernImagePicker(onPick: () => _pickImage(context)),

                  _label('Motto (optional)'),
                  _input(controller: _motto, hint: 'Club motto or tagline'),

                  const SizedBox(height: 32),

                  BlocBuilder<CreateClubCubit, CreateClubState>(
                    builder: (context, state) {
                      return SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: state.loading
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    final cubit = context
                                        .read<CreateClubCubit>();

                                    // 🔥 FORCE SYNC CONTROLLERS → CUBIT
                                    cubit.setName(_name.text.trim());
                                    cubit.setDescription(
                                      _description.text.trim(),
                                    );
                                    cubit.setLocation(_location.text.trim());
                                    cubit.togglePrivate(state.isPrivate);
                                    cubit.setMotto(_motto.text.trim());

                                    cubit.submit();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary_,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: state.loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Create Club',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /* ───────── UI HELPERS ───────── */

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        const Spacer(),
        const Text(
          'Create Club',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(text, style: const TextStyle(color: Colors.white70)),
  );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/* ──────────────────────────────── */
/* MODERN PRIVACY TOGGLE            */
/* ──────────────────────────────── */

class _PrivacyToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateClubCubit, CreateClubState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                state.isPrivate ? Icons.lock : Icons.public,
                color: Colors.white70,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.isPrivate ? 'Private club' : 'Public club',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: state.isPrivate,
                activeColor: AppColors.primary_,
                onChanged: (v) =>
                    context.read<CreateClubCubit>().togglePrivate(v),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ──────────────────────────────── */
/* ULTRA-MODERN IMAGE PICKER        */
/* ──────────────────────────────── */

class _ModernImagePicker extends StatelessWidget {
  final VoidCallback onPick;
  const _ModernImagePicker({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateClubCubit, CreateClubState>(
      builder: (context, state) {
        return GestureDetector(
          onTap: onPick,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              image: state.coverImageFile != null
                  ? DecorationImage(
                      image: FileImage(state.coverImageFile!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                if (state.coverImageFile == null)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Colors.white70,
                          size: 36,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add cover image',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                else
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
