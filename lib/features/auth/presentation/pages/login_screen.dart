import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_button.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:moonlight/features/auth/presentation/widgets/social_auth_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  'Welcome back to Moonlight',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue streaming and connecting',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.textWhite),
                ),
                const SizedBox(height: 40),
                AuthTextField(
                  controller: emailController,
                  label: 'Email address',
                  hint: 'Enter your email address',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      // TODO: Navigate to Forgot Password screen
                      Navigator.pushNamed(context, RouteNames.forget_password);
                    },
                    child: Text(
                      'Forgot Password?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                AuthButton(text: 'Login', onPressed: () {}),

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

                SocialAuthButton(
                  icon: AssetPaths.googleIcon,
                  text: 'Sign In with Google',
                  onPressed: () {
                    context.read<AuthBloc>().add(
                      const SocialLoginRequested('google'),
                    );
                  },
                ),

                // Uncomment other Social buttons if needed
                // const SizedBox(height: 12),
                // SocialAuthButton(...),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      // Navigate to Register page
                      Navigator.pushNamed(context, RouteNames.register);
                    },
                    child: Text(
                      'Sign up with Email',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                      // Navigate to Register page
                      Navigator.pushNamed(context, RouteNames.email_verify);
                    },
                    child: Text(
                      'Verify Email Page',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.bold,
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
  }
}
