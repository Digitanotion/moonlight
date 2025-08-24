import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_button.dart';
import 'package:moonlight/features/auth/presentation/widgets/social_auth_button.dart';
import 'package:moonlight/features/auth/presentation/widgets/terms_and_policy.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _nameController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is RegistrationSuccess) {
          print("✅ Registration successful");
          // Navigate to Interest Selection screen after successful registration
          Navigator.pushReplacementNamed(context, RouteNames.email_verify);
        } else if (state is AuthFailure) {
          // Show error if registration failed
          print("❌ Auth failed: ${state.message}");
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Create Your Moonlight Account',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join the community and start earning from your content',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.textWhite),
                  ),
                  const SizedBox(height: 40),
                  AuthTextField(
                    controller: _emailController,
                    label: 'Email address',
                    hint: 'Enter your email address',
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Enter your password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hint: 'Confirm your password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _nameController,
                    label: 'Agent Name',
                    hint: 'Enter agent name (optional)',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      if (state is AuthLoading) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.green,
                          ),
                        );
                      }
                      return AuthButton(
                        text: 'Create Account',
                        onPressed: () {
                          context.read<AuthBloc>().add(
                            SignUpRequested(
                              email: _emailController.text.trim(),
                              password: _passwordController.text.trim(),
                              agent_name: _nameController.text.trim(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'or continue with',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SocialAuthButton(
                    icon: AssetPaths
                        .googleIcon, // You might want to add a Google icon
                    text: 'Sign Up with Google',
                    onPressed: () {
                      context.read<AuthBloc>().add(
                        const GoogleSignInRequested(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(
                          context,
                          RouteNames.login,
                        );
                      },
                      child: Text(
                        'Already have an account? Login',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TermsAndPolicyText(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
