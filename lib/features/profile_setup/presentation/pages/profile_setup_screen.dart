// lib/features/profile_setup/presentation/pages/profile_setup_screen.dart
//
// Mandatory onboarding step — no Skip button. Client requirement: every
// user must supply fullname, country, gender, and phone before entering
// the app, since these are baseline fields the rest of the social
// experience (localization, personalization, contact) depends on.
// Bio and date of birth remain optional, matching ProfileSetupCubit's
// existing setBio/setDob methods.
//
// Country picker uses lib/core/utils/countries.dart (kIso2ToName,
// isoToFlagEmoji, allCountriesSorted) — the same source LiveFeedRemote
// DataSource already relies on for flags/ISO codes — instead of the old
// CountryLocalDataSource, which only returns bare name strings with no
// ISO code or flag support.
 
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/utils/countries.dart';
import 'package:moonlight/features/profile_setup/presentation/cubit/profile_setup_cubit.dart';
 
class _C {
  static const bg = Color(0xFF05060F);
  static const surface = Color(0xFF0E1024);
  static const border = Color(0xFF1A1D3D);
  static const accent = Color(0xFFFF6A00);
  static const textSecondary = Color(0xFF8B8FB8);
  static const success = Color(0xFF22C55E);
}
 
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
 
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}
 
class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _fullnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _picker = ImagePicker();
 
  @override
  void dispose() {
    _fullnameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }
 
  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked != null && mounted) {
      context.read<ProfileSetupCubit>().setAvatarPath(picked.path);
    }
  }
 
  void _openCountryPicker() async {
    final iso = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CountryPickerSheet(),
    );
    if (iso != null && mounted) {
      context.read<ProfileSetupCubit>().setCountry(iso);
    }
  }
 
  Future<void> _pickDob(DateTime? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _C.accent,
            surface: _C.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      context.read<ProfileSetupCubit>().setDob(picked);
    }
  }
 
  bool _isRequiredDone(ProfileSetupState s) {
    return s.fullname.trim().isNotEmpty &&
        (s.country ?? '').isNotEmpty &&
        (s.gender ?? '').isNotEmpty &&
        (s.phone ?? '').trim().length >= 7;
  }
 
  int _requiredFieldsFilledCount(ProfileSetupState s) {
    var count = 0;
    if (s.fullname.trim().isNotEmpty) count++;
    if ((s.country ?? '').isNotEmpty) count++;
    if ((s.gender ?? '').isNotEmpty) count++;
    if ((s.phone ?? '').trim().length >= 7) count++;
    return count;
  }
 
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileSetupCubit, ProfileSetupState>(
      listenWhen: (p, n) => p.success != n.success || p.error != n.error,
      listener: (context, state) {
        if (state.success) {
          Navigator.pushReplacementNamed(context, RouteNames.interests);
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final canContinue = _isRequiredDone(state);
        final filledCount = _requiredFieldsFilledCount(state);
 
        return Scaffold(
          backgroundColor: _C.bg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Stack(
                            children: [
                              Container(height: 6, color: _C.surface),
                              AnimatedFractionallySizedBox(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                widthFactor: filledCount / 4,
                                child: Container(
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [_C.accent, Color(0xFFFF9A3D)],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$filledCount/4',
                        style: TextStyle(
                          color: filledCount == 4 ? _C.success : _C.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
 
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          "Let's set you up",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A few basics so people can find and recognize you, '
                          'this only takes a minute.',
                          style: TextStyle(
                            color: _C.textSecondary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
 
                        const SizedBox(height: 18),
 
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _C.accent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _C.accent.withOpacity(0.25)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _C.accent.withOpacity(0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.info_outline_rounded,
                                    size: 16, color: _C.accent),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.45,
                                      color: Colors.white70,
                                    ),
                                    children: [
                                      const TextSpan(text: 'The fields marked '),
                                      const TextSpan(
                                        text: '*',
                                        style: TextStyle(
                                          color: _C.accent,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const TextSpan(
                                        text:
                                            ' are required to keep the community '
                                            'genuine and help us personalize your feed. '
                                            'Everything else is optional — add it '
                                            'anytime later from your profile.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
 
                        const SizedBox(height: 26),
 
                        Center(
                          child: GestureDetector(
                            onTap: _pickAvatar,
                            child: Stack(
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1B2153),
                                        Color(0xFF0F1432),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: _C.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: state.avatarPath != null
                                        ? Image.file(
                                            File(state.avatarPath!),
                                            fit: BoxFit.cover,
                                            width: 96,
                                            height: 96,
                                          )
                                        : const Icon(
                                            Icons.person_rounded,
                                            color: Colors.white38,
                                            size: 40,
                                          ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: _C.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Add a photo (optional)',
                            style: TextStyle(
                              color: _C.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
 
                        const SizedBox(height: 32),
 
                        const _FieldLabel(text: 'Full name', required: true),
                        const SizedBox(height: 6),
                        Text(
                          "This is how people will recognize you across Moonlight.",
                          style: TextStyle(color: _C.textSecondary, fontSize: 11.5),
                        ),
                        const SizedBox(height: 8),
                        _TextField(
                          controller: _fullnameCtrl,
                          hint: 'e.g. Divine Wood',
                          icon: Icons.badge_rounded,
                          onChanged: (v) =>
                              context.read<ProfileSetupCubit>().setFullname(v),
                          textCapitalization: TextCapitalization.words,
                        ),
 
                        const SizedBox(height: 22),
 
                        const _FieldLabel(text: 'Country', required: true),
                        const SizedBox(height: 6),
                        Text(
                          "Helps us show you local creators, clubs and content.",
                          style: TextStyle(color: _C.textSecondary, fontSize: 11.5),
                        ),
                        const SizedBox(height: 8),
                        _CountrySelectField(
                          iso2: state.country,
                          onTap: _openCountryPicker,
                        ),
 
                        const SizedBox(height: 22),
 
                        const _FieldLabel(text: 'Gender', required: true),
                        const SizedBox(height: 6),
                        Text(
                          "Used to personalize your experience — never shared publicly beyond your profile.",
                          style: TextStyle(color: _C.textSecondary, fontSize: 11.5),
                        ),
                        const SizedBox(height: 10),
                        _GenderSelector(
                          selected: state.gender,
                          onSelect: (g) =>
                              context.read<ProfileSetupCubit>().setGender(g),
                        ),
 
                        const SizedBox(height: 22),
 
                        const _FieldLabel(text: 'Phone number', required: true),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 12, color: _C.textSecondary),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Only used for account security — never shown on your profile.',
                                style: TextStyle(color: _C.textSecondary, fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _TextField(
                          controller: _phoneCtrl,
                          hint: 'e.g. 08012345678',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\s]'),
                            ),
                          ],
                          onChanged: (v) =>
                              context.read<ProfileSetupCubit>().setPhone(v),
                        ),
 
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Expanded(child: Divider(color: _C.border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OPTIONAL',
                                style: TextStyle(
                                  color: _C.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: _C.border)),
                          ],
                        ),
                        const SizedBox(height: 22),
 
                        const _FieldLabel(text: 'Bio'),
                        const SizedBox(height: 6),
                        Text(
                          "A short line about yourself — shows up on your profile.",
                          style: TextStyle(color: _C.textSecondary, fontSize: 11.5),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: _C.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _C.border),
                          ),
                          child: TextField(
                            controller: _bioCtrl,
                            maxLines: 3,
                            maxLength: 150,
                            style: const TextStyle(color: Colors.white, fontSize: 14.5),
                            onChanged: (v) =>
                                context.read<ProfileSetupCubit>().setBio(v),
                            decoration: InputDecoration(
                              hintText: "e.g. Streamer, gamer, coffee addict ☕",
                              hintStyle: TextStyle(color: _C.textSecondary.withOpacity(0.7)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                              counterStyle: TextStyle(color: _C.textSecondary, fontSize: 11),
                            ),
                          ),
                        ),
 
                        const SizedBox(height: 22),
 
                        const _FieldLabel(text: 'Date of birth'),
                        const SizedBox(height: 6),
                        Text(
                          "Helps us tailor age-appropriate content for you.",
                          style: TextStyle(color: _C.textSecondary, fontSize: 11.5),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _pickDob(state.dob),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: _C.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _C.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.cake_outlined,
                                    color: _C.textSecondary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    state.dob != null
                                        ? _formatDob(state.dob!)
                                        : 'Select your date of birth',
                                    style: TextStyle(
                                      color: state.dob != null
                                          ? Colors.white
                                          : _C.textSecondary.withOpacity(0.7),
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: _C.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
 
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    children: [
                      if (!canContinue)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Fill in the ${4 - filledCount} remaining required '
                            'field${4 - filledCount == 1 ? '' : 's'} to continue',
                            style: TextStyle(
                              color: _C.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: (canContinue && !state.submitting)
                              ? () => context.read<ProfileSetupCubit>().submit()
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _C.accent,
                            disabledBackgroundColor: _C.accent.withOpacity(0.25),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: state.submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
 
  String _formatDob(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
 
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel({required this.text, this.required = false});
 
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: _C.accent, fontSize: 14)),
        ],
      ],
    );
  }
}
 
class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
 
  const _TextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });
 
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _C.textSecondary, size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: _C.textSecondary.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
 
class _CountrySelectField extends StatelessWidget {
  final String? iso2;
  final VoidCallback onTap;
  const _CountrySelectField({required this.iso2, required this.onTap});
 
  @override
  Widget build(BuildContext context) {
    final hasValue = (iso2 ?? '').isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            if (hasValue) ...[
              Text(isoToFlagEmoji(iso2!), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
            ] else ...[
              Icon(Icons.public_rounded, color: _C.textSecondary, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                hasValue ? countryDisplayName(iso2) : 'Select your country',
                style: TextStyle(
                  color: hasValue ? Colors.white : _C.textSecondary.withOpacity(0.7),
                  fontSize: 14.5,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _C.textSecondary),
          ],
        ),
      ),
    );
  }
}
 
class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();
 
  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}
 
class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late final List<MapEntry<String, String>> _all;
  List<MapEntry<String, String>> _filtered = [];
  final _searchCtrl = TextEditingController();
 
  @override
  void initState() {
    super.initState();
    _all = allCountriesSorted();
    _filtered = _all;
    _searchCtrl.addListener(_onSearch);
  }
 
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
 
  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
              .where((e) =>
                  e.value.toLowerCase().contains(q) ||
                  e.key.toLowerCase().contains(q))
              .toList();
    });
  }
 
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: const BoxDecoration(
          color: _C.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Select country',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded,
                        color: _C.textSecondary, size: 20),
                    hintText: 'Search countries…',
                    hintStyle: TextStyle(color: _C.textSecondary.withOpacity(0.7)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No countries found',
                        style: TextStyle(color: _C.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final entry = _filtered[i];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context, entry.key),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    isoToFlagEmoji(entry.key),
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
 
class _GenderSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  const _GenderSelector({required this.selected, required this.onSelect});
 
  static const _options = [
    ('male', 'Male', Icons.male_rounded),
    ('female', 'Female', Icons.female_rounded),
    ('other', 'Other', Icons.transgender_rounded),
    ('prefer_not_to_say', "Prefer not to say", Icons.visibility_off_rounded),
  ];
 
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _options.map((opt) {
        final (value, label, icon) = opt;
        final isSelected = selected == value;
        return GestureDetector(
          onTap: () => onSelect(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? _C.accent.withOpacity(0.16) : _C.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _C.accent : _C.border,
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? _C.accent : _C.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : _C.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}