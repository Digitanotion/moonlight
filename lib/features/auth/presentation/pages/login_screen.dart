import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_button.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:moonlight/features/auth/presentation/widgets/custom_status_dialog.dart';
import 'package:moonlight/features/auth/presentation/widgets/social_auth_button.dart';
import 'package:moonlight/shared/widgets/custom_status_dialog.dart'; // <- make sure path is correct

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void _onLoginPressed(BuildContext context) {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => CustomStatusDialog(
          type: StatusDialogType.failure,
          title: "Missing Info",
          message: "Please enter both email and password.",
          primaryButtonText: 'Try Again',
          onPrimaryPressed: () {
            Navigator.pop(context);
          },
        ),
      );
      return;
    }

    context.read<AuthBloc>().add(
      LoginWithEmailRequested(email: email, password: password),
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
            end: Alignment.topRight,
          ),
        ),
        child: SafeArea(
          child: BlocConsumer<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthAuthenticated) {
                // ✅ Show success dialog
                showDialog(
                  context: context,
                  builder: (_) => CustomStatusDialog(
                    type: StatusDialogType.success,
                    title: 'Login Successful',
                    message:
                        'Welcome back, ${state.user.name ?? "Moonlighter"}!',
                    primaryButtonText: 'Continue',
                    onPrimaryPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(
                        context,
                        RouteNames.home, // adjust if your home route differs
                      );
                    },
                  ),
                );
              } else if (state is AuthFailure) {
                // Show error dialog
                showDialog(
                  context: context,
                  builder: (_) => CustomStatusDialog(
                    type: StatusDialogType.failure,
                    title: 'Login Failed',
                    message: state.message,
                    primaryButtonText: 'Try Again',
                    onPrimaryPressed: () {
                      Navigator.pop(context);
                    },
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
                      'Welcome back to Moonlight',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textWhite,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue streaming and connecting',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Email
                    AuthTextField(
                      controller: emailController,
                      label: 'Email address',
                      hint: 'Enter your email address',
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    AuthTextField(
                      controller: passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 8),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            RouteNames.forget_password,
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textRed,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ✅ Login Button
                    AuthButton(
                      text: state is AuthLoading ? 'Logging in...' : 'Login',
                      onPressed: state is AuthLoading
                          ? null
                          : () => _onLoginPressed(context),
                    ),

                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'or',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Google login
                    SocialAuthButton(
                      icon: AssetPaths.googleIcon,
                      text: 'Sign In with Google',
                      onPressed: () {
                        context.read<AuthBloc>().add(
                          const SocialLoginRequested('google'),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, RouteNames.register);
                        },
                        child: Text(
                          'Sign up with Email',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, RouteNames.email_verify);
                        },
                        child: Text(
                          'Verify Email Page',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textWhite,
                                fontWeight: FontWeight.bold,
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
