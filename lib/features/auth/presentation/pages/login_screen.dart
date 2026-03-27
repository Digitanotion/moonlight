import 'dart:ui';
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
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:moonlight/widgets/moon_snack.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
          ),
        );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

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
          onPrimaryPressed: () => Navigator.pop(context),
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────────
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.dark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative orbs for depth ────────────────────────────────────
          Positioned(
            top: -80,
            right: -60,
            child: _GlowOrb(
              size: 260,
              color: AppColors.primary.withOpacity(0.35),
            ),
          ),
          Positioned(
            bottom: size.height * 0.15,
            left: -80,
            child: _GlowOrb(size: 200, color: AppColors.dark.withOpacity(0.5)),
          ),

          // ── Main scrollable content ──────────────────────────────────────
          SafeArea(
            child: BlocConsumer<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthAuthenticated) {
                  // Check whether this user has completed profile setup.
                  // OnboardingBloc loads 'hasCompletedProfile' from SharedPrefs.
                  final hasCompletedProfile = context
                      .read<OnboardingBloc>()
                      .state
                      .hasCompletedProfile;

                  debugPrint(
                    '\U0001f510 Login success — hasCompletedProfile=\$hasCompletedProfile',
                  );

                  if (!hasCompletedProfile) {
                    // First login or profile was skipped — go to setup once.
                    Navigator.pushReplacementNamed(
                      context,
                      RouteNames.profile_setup,
                    );
                  } else {
                    // Returning user with profile done — straight to home.
                    Navigator.pushReplacementNamed(context, RouteNames.home);
                  }
                } else if (state is AuthFailure) {
                  debugPrint(state.message);
                  MoonSnack.error(context, state.message);
                }
              },
              builder: (context, state) {
                final isEmailLoading =
                    state is AuthLoading &&
                    (state.loadingType == 'email' || state.loadingType == null);
                final isGoogleLoading =
                    state is AuthLoading && state.loadingType == 'google';

                return FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // ── Moon icon / brand mark ───────────────────────
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.nights_stay_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Headline ─────────────────────────────────────
                          Text(
                            'Welcome back',
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to keep streaming and connecting.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.white.withOpacity(0.65),
                                  height: 1.5,
                                ),
                          ),

                          const SizedBox(height: 40),

                          // ── Frosted card ─────────────────────────────────
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.09),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
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

                                    const SizedBox(height: 12),

                                    // Forgot password
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: GestureDetector(
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          RouteNames.forget_password,
                                        ),
                                        child: Text(
                                          'Forgot Password?',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.textRed,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 28),

                                    // Login button
                                    AuthButton(
                                      text: isEmailLoading
                                          ? 'Signing in…'
                                          : 'Sign In',
                                      onPressed: isEmailLoading
                                          ? null
                                          : () => _onLoginPressed(context),
                                    ),

                                    const SizedBox(height: 20),

                                    // Divider
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            thickness: 1,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            'or continue with',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.white
                                                      .withOpacity(0.45),
                                                ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            thickness: 1,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 20),

                                    // Google sign-in
                                    SocialAuthButton(
                                      icon: AssetPaths.googleIcon,
                                      text: isGoogleLoading
                                          ? 'Signing in…'
                                          : 'Sign In with Google',
                                      onPressed: () {
                                        if (!isGoogleLoading) {
                                          context.read<AuthBloc>().add(
                                            const GoogleSignInRequested(),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Sign-up prompt ───────────────────────────────
                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                context,
                                RouteNames.register,
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withOpacity(0.55),
                                      ),
                                  children: [
                                    const TextSpan(
                                      text: "Or Sign up with your ",
                                    ),
                                    TextSpan(
                                      text: 'email',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
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
    );
  }
}

/// Soft glowing circle used as a background decoration.
class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}
