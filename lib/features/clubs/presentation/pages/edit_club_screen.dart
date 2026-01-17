import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/presentation/cubit/edit_club_cubit.dart';
import 'package:moonlight/features/clubs/presentation/cubit/edit_club_state.dart';

class EditClubScreen extends StatelessWidget {
  final String clubUuid;

  const EditClubScreen({super.key, required this.clubUuid});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          EditClubCubit(repository: sl<ClubsRepository>(), clubUuid: clubUuid)
            ..load(),
      child: const _EditClubView(),
    );
  }
}

/* ───────────────────────────────────────────── */

class _EditClubView extends StatefulWidget {
  const _EditClubView();

  @override
  State<_EditClubView> createState() => _EditClubViewState();
}

class _EditClubViewState extends State<_EditClubView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _motto = TextEditingController();
  final _picker = ImagePicker();
  bool _hydrated = false;

  // Toast controller for managing toast display
  FToast? fToast;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fToast = FToast();
      fToast!.init(context);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    _motto.dispose();
    super.dispose();
  }

  Future<void> _pickImage(BuildContext context) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    context.read<EditClubCubit>().setCoverImage(File(file.path));
  }

  // Professional Success Toast
  void _showSuccessToast(String message) {
    fToast?.showToast(
      child: _buildToastContainer(
        icon: Icons.check_circle,
        iconColor: Colors.green,
        backgroundColor: Colors.green.withOpacity(0.15),
        borderColor: Colors.green.withOpacity(0.3),
        message: message,
      ),
      gravity: ToastGravity.TOP,
      toastDuration: const Duration(seconds: 3),
    );
  }

  // Professional Error Toast
  void _showErrorToast(String message) {
    fToast?.showToast(
      child: _buildToastContainer(
        icon: Icons.error_outline,
        iconColor: Colors.red,
        backgroundColor: Colors.red.withOpacity(0.15),
        borderColor: Colors.red.withOpacity(0.3),
        message: message,
      ),
      gravity: ToastGravity.TOP,
      toastDuration: const Duration(seconds: 4),
    );
  }

  // Professional Warning Toast
  void _showWarningToast(String message) {
    fToast?.showToast(
      child: _buildToastContainer(
        icon: Icons.warning_amber,
        iconColor: Colors.orange,
        backgroundColor: Colors.orange.withOpacity(0.15),
        borderColor: Colors.orange.withOpacity(0.3),
        message: message,
      ),
      gravity: ToastGravity.TOP,
      toastDuration: const Duration(seconds: 3),
    );
  }

  // Reusable Toast Container Widget
  Widget _buildToastContainer({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Simple toast (if you want a simpler version)
  void _showSimpleToast(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP,
      timeInSecForIosWeb: 2,
      backgroundColor: isError ? Colors.red : Colors.green,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditClubCubit, EditClubState>(
      listenWhen: (previous, current) =>
          previous.updatedClub != current.updatedClub ||
          previous.errorMessage != current.errorMessage ||
          previous.loading != current.loading,
      listener: (context, state) {
        // Handle success
        if (state.updatedClub != null) {
          _showSuccessToast('Club updated successfully!');

          // Delay navigation to show toast first
          Future.delayed(const Duration(milliseconds: 1500), () {
            Navigator.pushReplacementNamed(
              context,
              RouteNames.clubProfile,
              arguments: {'clubUuid': state.updatedClub!.uuid},
            );
          });
        }

        // Handle errors
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          _showErrorToast(state.errorMessage!);
        }

        // Handle save completion (even if no navigation)
        if (!state.loading &&
            state.errorMessage == null &&
            state.updatedClub == null) {
          // This could be for auto-save or partial updates
          _showSuccessToast('Changes saved');
        }
      },
      builder: (context, state) {
        // Show loading toast when saving
        if (state.loading && _hydrated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showLoadingToast();
          });
        }

        /// 🔑 Hydrate controllers ONCE after load
        if (!_hydrated && !state.loading) {
          _name.text = state.name;
          _description.text = state.description ?? '';
          _location.text = state.location ?? '';
          _motto.text = state.motto ?? '';
          _hydrated = true;
        }

        if (state.loading && !_hydrated) {
          return const Scaffold(
            backgroundColor: AppColors.bgBottom,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Club name is required';
                        }
                        if (v.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                      onChanged: context.read<EditClubCubit>().setName,
                    ),

                    _label('Description'),
                    _input(
                      controller: _description,
                      hint: 'What is this club about?',
                      maxLines: 4,
                      onChanged: context.read<EditClubCubit>().setDescription,
                    ),

                    _label('Location'),
                    _input(
                      controller: _location,
                      hint: 'City, Country',
                      onChanged: context.read<EditClubCubit>().setLocation,
                    ),

                    _label('Privacy'),
                    const SizedBox(height: 8),
                    const _PrivacyToggle(),

                    _label('Cover image'),
                    const SizedBox(height: 8),
                    _ModernImagePicker(onPick: () => _pickImage(context)),

                    _label('Motto (optional)'),
                    _input(
                      controller: _motto,
                      hint: 'Club motto or tagline',
                      onChanged: context.read<EditClubCubit>().setMotto,
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: state.loading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  // Show saving indicator
                                  _showSavingIndicator();
                                  context.read<EditClubCubit>().submit();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary_,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: state.loading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Saving...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
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

  void _showLoadingToast() {
    fToast?.showToast(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.blue.withOpacity(0.15),
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Saving changes...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      gravity: ToastGravity.TOP,
      toastDuration: const Duration(seconds: 60), // Long duration for loading
    );
  }

  void _showSavingIndicator() {
    // Remove any existing toast first
    fToast?.removeCustomToast();

    fToast?.showToast(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.blue.withOpacity(0.15),
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Saving your changes...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      gravity: ToastGravity.TOP,
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
          'Edit Club',
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
    required void Function(String) onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
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
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }
}

/* ──────────────────────────────── */
/* PRIVACY TOGGLE                  */
/* ──────────────────────────────── */

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditClubCubit, EditClubState>(
      buildWhen: (p, c) => p.isPrivate != c.isPrivate,
      builder: (context, state) {
        final bool isPrivate = state.isPrivate ?? false;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                isPrivate ? Icons.lock : Icons.public,
                color: Colors.white70,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPrivate ? 'Private club' : 'Public club',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: isPrivate,
                activeColor: AppColors.primary_,
                onChanged: context.read<EditClubCubit>().togglePrivate,
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ──────────────────────────────── */
/* IMAGE PICKER                    */
/* ──────────────────────────────── */

class _ModernImagePicker extends StatelessWidget {
  final VoidCallback onPick;
  const _ModernImagePicker({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditClubCubit, EditClubState>(
      buildWhen: (p, c) =>
          p.newCoverImage != c.newCoverImage ||
          p.existingCoverUrl != c.existingCoverUrl,
      builder: (context, state) {
        ImageProvider? image;

        if (state.newCoverImage != null) {
          image = FileImage(state.newCoverImage!);
        } else if (state.existingCoverUrl != null) {
          image = NetworkImage(state.existingCoverUrl!);
        }

        return GestureDetector(
          onTap: onPick,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.06),
              image: image != null
                  ? DecorationImage(image: image, fit: BoxFit.cover)
                  : null,
            ),
            child: Stack(
              children: [
                if (image == null)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          color: Colors.white70,
                          size: 40,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Change cover image',
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
