// lib/features/clubs/presentation/pages/club_treasury_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/clubs/presentation/cubit/club_treasury_cubit.dart';
import 'package:moonlight/features/clubs/data/datasources/club_treasury_remote_data_source.dart';
import 'package:moonlight/widgets/top_snack.dart';

class ClubTreasurySetupScreen extends StatefulWidget {
  final String clubUuid;
  final bool pinOnly;

  const ClubTreasurySetupScreen({
    super.key,
    required this.clubUuid,
    this.pinOnly = false,
  });

  @override
  State<ClubTreasurySetupScreen> createState() =>
      _ClubTreasurySetupScreenState();
}

class _ClubTreasurySetupScreenState extends State<ClubTreasurySetupScreen> {
  int _step = 0; // 0=PIN, 1=done
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _currentPinController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isChanging = false; // true when updating existing PIN

  @override
  void dispose() {
    _newPinController.dispose();
    _confirmPinController.dispose();
    _currentPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ClubTreasuryCubit(
        ctx.read<ClubTreasuryRemoteDataSource>(),
        widget.clubUuid,
      )..load(),
      child: BlocConsumer<ClubTreasuryCubit, ClubTreasuryState>(
        listener: (context, state) {
          if (state.error != null) {
            TopSnack.error(context, state.error!);
            context.read<ClubTreasuryCubit>().clearMessages();
          }
          if (state.success != null) {
            TopSnack.success(context, state.success!);
            context.read<ClubTreasuryCubit>().clearMessages();
            if (widget.pinOnly) Navigator.pop(context);
          }
          if (state.summary != null) {
            _isChanging = state.summary!.treasuryReady;
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppColors.bgBottom,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.bgTop, AppColors.bgBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildPinStep(context, state),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isChanging ? 'Change Treasury PIN' : 'Set Up Treasury PIN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinStep(BuildContext context, ClubTreasuryState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7A00), Color(0xFFFF9F40)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7A00).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            _isChanging
                ? 'Change Club Treasury PIN'
                : 'Create Club Treasury PIN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'This 6-digit PIN is separate from your personal wallet PIN.\nAll admins share this club PIN to approve withdrawals.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 32),

        if (_isChanging) ...[
          _PinField(
            controller: _currentPinController,
            label: 'Current Treasury PIN',
            hint: 'Enter existing 6-digit PIN',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
          ),
          const SizedBox(height: 16),
        ],

        _PinField(
          controller: _newPinController,
          label: _isChanging ? 'New Treasury PIN' : 'Treasury PIN',
          hint: 'Enter 6 digits',
          obscure: _obscureNew,
          onToggle: () => setState(() => _obscureNew = !_obscureNew),
        ),
        const SizedBox(height: 16),
        _PinField(
          controller: _confirmPinController,
          label: 'Confirm PIN',
          hint: 'Re-enter 6 digits',
          obscure: _obscureConfirm,
          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        const SizedBox(height: 12),

        // PIN requirements
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _PinRequirement(
                met: _newPinController.text.length == 6,
                label: 'Exactly 6 digits',
              ),
              const SizedBox(height: 6),
              _PinRequirement(
                met:
                    _newPinController.text == _confirmPinController.text &&
                    _newPinController.text.isNotEmpty,
                label: 'PINs match',
              ),
              const SizedBox(height: 6),
              _PinRequirement(
                met:
                    RegExp(r'^\d+$').hasMatch(_newPinController.text) &&
                    _newPinController.text.isNotEmpty,
                label: 'Numbers only',
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Warning box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Share this PIN with other club admins carefully. '
                  'Anyone with this PIN can approve or request withdrawals.',
                  style: TextStyle(
                    color: Colors.orange.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.submitting ? null : () => _submit(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: state.submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isChanging ? 'Update PIN' : 'Save Treasury PIN',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    final newPin = _newPinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (newPin.length != 6 || !RegExp(r'^\d+$').hasMatch(newPin)) {
      TopSnack.error(context, 'PIN must be exactly 6 digits.');
      return;
    }
    if (newPin != confirm) {
      TopSnack.error(context, 'PINs do not match.');
      return;
    }

    final currentPin = _isChanging ? _currentPinController.text.trim() : null;

    context.read<ClubTreasuryCubit>().setPin(newPin, currentPin: currentPin);
  }
}

class _PinField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;

  const _PinField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscure,
    required this.onToggle,
  });

  @override
  State<_PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<_PinField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: TextField(
            controller: widget.controller,
            obscureText: widget.obscure,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 8,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
                letterSpacing: 0,
              ),
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  widget.obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white54,
                ),
                onPressed: widget.onToggle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PinRequirement extends StatelessWidget {
  final bool met;
  final String label;

  const _PinRequirement({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          met
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: met ? Colors.greenAccent : Colors.white38,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: met ? Colors.greenAccent : Colors.white38,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
