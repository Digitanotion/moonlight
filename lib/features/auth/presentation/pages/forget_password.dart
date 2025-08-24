import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_button.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:moonlight/features/auth/presentation/widgets/custom_status_dialog.dart';
import 'package:moonlight/features/auth/presentation/widgets/social_auth_button.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final emailController = TextEditingController();

  void _sendResetLink(BuildContext context) {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => CustomStatusDialog(
          type: StatusDialogType.failure,
          title: 'Missing Email',
          message: 'Please enter your email address.',
          primaryButtonText: 'Try Again',
          onPrimaryPressed: () => Navigator.pop(context),
        ),
      );
      return;
    }

    context.read<AuthBloc>().add(ForgotPasswordRequested(email: email));
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
            end: Alignment.topRight,
          ),
        ),
        child: SafeArea(
          child: BlocConsumer<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthForgotPasswordSuccess) {
                showDialog(
                  context: context,
                  builder: (_) => CustomStatusDialog(
                    type: StatusDialogType.success,
                    title: 'Reset Link Sent',
                    message: state.message,
                    primaryButtonText: 'Sign In',
                    onPrimaryPressed: () =>
                        Navigator.pushNamed(context, RouteNames.login),
                  ),
                );
              } else if (state is AuthFailure) {
                showDialog(
                  context: context,
                  builder: (_) => CustomStatusDialog(
                    type: StatusDialogType.failure,
                    title: 'Failed',
                    message: state.message,
                    primaryButtonText: 'Try Again',
                    onPrimaryPressed: () => Navigator.pop(context),
                  ),
                );
              }
            },
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Text(
                      'Forgot Password',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textWhite,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your email address and we'll send you a link to reset your password",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 80),
                    AuthTextField(
                      controller: emailController,
                      label: 'Email address',
                      hint: 'Enter your email address',
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 32),
                    AuthButton(
                      text: state is AuthLoading
                          ? 'Sending...'
                          : 'Send Reset Link',
                      onPressed: state is AuthLoading
                          ? null
                          : () => _sendResetLink(context),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, RouteNames.login),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textWhite),
                            children: const [
                              TextSpan(text: 'Remember your password? '),
                              TextSpan(
                                text: 'Back to Login',
                                style: TextStyle(
                                  color: AppColors.green,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
