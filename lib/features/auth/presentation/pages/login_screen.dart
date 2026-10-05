import 'dart:async';
import 'package:moonlight/core/services/pending_agent_code_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_ui.dart';
import 'package:moonlight/features/auth/presentation/widgets/custom_status_dialog.dart';
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

  // Guards against double-navigation if AuthBloc emits AuthAuthenticated
  // more than once (e.g. a token-refresh emission) while we're still
  // resolving the profile-completion check for the first one.
  bool _resolvingPostLogin = false;

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

  /// Runs the authoritative, live profile-completion check right after a
  /// successful login, rather than trusting whatever value happened to
  /// already be sitting in OnboardingBloc's state (which could easily be
  /// stale — loaded from cache before this login ever happened). Bounded
  /// by a short timeout so a slow/no connection can't hang the login
  /// flow; on timeout it falls back to whatever the bloc already has
  /// rather than blocking indefinitely.
  Future<void> _resolvePostLoginRoute(BuildContext context) async {
    if (_resolvingPostLogin) return;
    _resolvingPostLogin = true;
    // Attach to an inviting agent now (the account is authenticated), not
    // later at Home — new users go through profile setup first.
    PendingAgentCodeService.applyIfPending();

    final onboardingBloc = context.read<OnboardingBloc>();

    try {
      // Fire the live check and wait for the NEXT state it produces,
      // rather than reading the bloc's current (possibly stale) state.
      final updatedStateFuture = onboardingBloc.stream.first;
      onboardingBloc.add(const CheckFirstLaunchStatus());

      final updated = await updatedStateFuture.timeout(
        const Duration(seconds: 4),
        onTimeout: () => onboardingBloc.state,
      );

      if (!mounted) return;

      debugPrint(
        '🔐 Login success — hasCompletedProfile=${updated.hasCompletedProfile}',
      );

      if (!updated.hasCompletedProfile) {
        Navigator.pushReplacementNamed(context, RouteNames.profile_setup);
      } else {
        Navigator.pushReplacementNamed(context, RouteNames.home);
      }
    } finally {
      _resolvingPostLogin = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: kAuthBgBottom,
      body: Stack(
        children: [
          const AuthBackdrop(),
          SafeArea(
            child: BlocConsumer<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthAuthenticated) {
                  _resolvePostLoginRoute(context);
                } else if (state is AuthFailure) {
                  debugPrint(state.message);
                  MoonSnack.error(context, state.message);
                }
              },
              builder: (context, state) {
                final emailLoading =
                    state is AuthLoading &&
                    (state.loadingType == 'email' || state.loadingType == null);
                final googleLoading =
                    state is AuthLoading && state.loadingType == 'google';
                final busy = emailLoading || googleLoading;

                return FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Align(
                            alignment: Alignment.centerRight,
                            child: AuthBrand(),
                          ),
                          const SizedBox(height: 44),
                          const Text(
                            'Welcome\nback',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              height: 1.05,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Sign in to keep streaming and connecting.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 30),
                          AuthGoogleButton(
                            loading: googleLoading,
                            onTap: busy
                                ? null
                                : () => context.read<AuthBloc>().add(
                                    const GoogleSignInRequested(),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          const AuthOrDivider(label: 'or sign in with email'),
                          const SizedBox(height: 20),
                          AuthGlass(
                            child: Column(
                              children: [
                                AuthField(
                                  controller: emailController,
                                  label: 'Email',
                                  icon: Icons.mail_outline_rounded,
                                  keyboard: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 14),
                                AuthField(
                                  controller: passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  password: true,
                                  last: true,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => Navigator.pushNamed(
                                      context,
                                      RouteNames.forget_password,
                                    ),
                                    child: const Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                        color: kAuthAccentSoft,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AuthPrimaryButton(
                                  label: 'Sign in',
                                  loading: emailLoading,
                                  onTap: busy
                                      ? null
                                      : () => _onLoginPressed(context),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                context,
                                RouteNames.register,
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 14.5,
                                  ),
                                  children: const [
                                    TextSpan(text: "Don't have an account?  "),
                                    TextSpan(
                                      text: 'Create one',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
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
    );
  }
}
