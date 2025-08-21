import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_button.dart';
import 'package:moonlight/features/auth/presentation/widgets/custom_status_dialog.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool isButtonEnabled = false;
  int resendSeconds = 45;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      _controllers[i].addListener(_onCodeChanged);
    }
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged() {
    setState(() {
      isButtonEnabled = _controllers.every((c) => c.text.isNotEmpty);
    });
    for (int i = 0; i < 5; i++) {
      if (_controllers[i].text.isNotEmpty) {
        _focusNodes[i + 1].requestFocus();
      }
    }
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (resendSeconds > 0) {
        setState(() {
          resendSeconds--;
        });
        _startResendTimer();
      }
    });
  }

  void _onResend() {
    if (resendSeconds == 0) {
      // Trigger resend email via AuthBloc
      // context.read<AuthBloc>().add(ResendEmailVerification(widget.email));
      setState(() {
        resendSeconds = 45;
      });
      _startResendTimer();
    }
  }

  void _onVerify() {
    final code = _controllers.map((c) => c.text).join();
    // context.read<AuthBloc>().add(VerifyEmailRequested(widget.email, code));
  }

  Widget _buildCodeField(int index) {
    return SizedBox(
      width: 45,
      height: 55,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 20),
        maxLength: 1,
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.dotInactive,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: index == 0 ? AppColors.primary : Colors.grey.shade700,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.email_outlined,
                      size: 48,
                      color: AppColors.primary_2,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Check Your Email',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "We've sent a 6-digit code to your email address.\nEnter it below to verify your account.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 60),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        6,
                        (index) => _buildCodeField(index),
                      ),
                    ),
                    const SizedBox(height: 25),
                    GestureDetector(
                      onTap: _onResend,
                      child: Text(
                        resendSeconds > 0
                            ? 'Didn\'t get the code? Resend in ${resendSeconds}s'
                            : 'Resend Code',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    AuthButton(
                      text: 'Verify & Continue',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => CustomStatusDialog(
                            type: StatusDialogType.success,
                            title: 'Account Verified',
                            message:
                                'Welcome to Moonlight. Let’s set up your profile to get started.',
                            primaryButtonText: 'Set Up My Profile',
                            onPrimaryPressed: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(
                                context,
                                RouteNames.profile_setup,
                              );
                            },
                            secondaryButtonText: 'Skip For Now',
                            onSecondaryPressed: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(
                                context,
                                RouteNames.interests,
                              );
                            },
                          ),
                        );
                      }, //isButtonEnabled ? _onVerify : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
