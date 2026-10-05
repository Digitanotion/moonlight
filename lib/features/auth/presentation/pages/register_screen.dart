// lib/features/auth/presentation/pages/register_screen.dart
//
// Sign-up: Google or email. A pending agent invite code (saved when an invite
// link is opened) stays stored, so the account is
// attached to that agent on first login — see PendingAgentCodeService.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_ui.dart';
import 'package:moonlight/features/auth/presentation/widgets/terms_and_policy.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:moonlight/widgets/moon_snack.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();

  late final AnimationController _anim;
  bool _resolvingPostLogin = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _anim.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    super.dispose();
  }

  // ── actions ──────────────────────────────────────────────────────────

  void _submitEmail() {
    final email = _email.text.trim();
    final pass = _password.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      MoonSnack.error(context, 'Enter a valid email address.');
      return;
    }
    if (pass.length < 8) {
      MoonSnack.error(context, 'Password must be at least 8 characters.');
      return;
    }
    if (pass != _confirm.text.trim()) {
      MoonSnack.error(context, 'Passwords do not match.');
      return;
    }
    HapticFeedback.lightImpact();
    context.read<AuthBloc>().add(
      SignUpRequested(
        email: email,
        password: pass,
        agent_name: _name.text.trim(),
      ),
    );
  }

  void _google() {
    HapticFeedback.lightImpact();
    context.read<AuthBloc>().add(const GoogleSignInRequested());
  }

  /// Same live profile-completion check the login screen runs after a
  /// successful sign-in (Google sign-up lands here as AuthAuthenticated).
  Future<void> _resolvePostLoginRoute(BuildContext context) async {
    if (_resolvingPostLogin) return;
    _resolvingPostLogin = true;
    final onboarding = context.read<OnboardingBloc>();
    try {
      final next = onboarding.stream.first;
      onboarding.add(const CheckFirstLaunchStatus());
      final updated = await next.timeout(
        const Duration(seconds: 4),
        onTimeout: () => onboarding.state,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        this.context,
        updated.hasCompletedProfile
            ? RouteNames.home
            : RouteNames.profile_setup,
      );
    } finally {
      _resolvingPostLogin = false;
    }
  }

  // ── password strength (0..4) ─────────────────────────────────────────

  int get _strength {
    final p = _password.text;
    if (p.isEmpty) return 0;
    var s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  // ── build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is RegistrationSuccess) {
          Navigator.pushReplacementNamed(context, RouteNames.email_verify);
        } else if (state is AuthAuthenticated) {
          _resolvePostLoginRoute(context);
        } else if (state is AuthFailure) {
          MoonSnack.error(context, state.message);
        }
      },
      builder: (context, state) {
        final emailLoading =
            state is AuthLoading &&
            (state.loadingType == 'register' || state.loadingType == null);
        final googleLoading =
            state is AuthLoading && state.loadingType == 'google';
        final busy = emailLoading || googleLoading;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: kAuthBgBottom,
          body: Stack(
            children: [
              const AuthBackdrop(),
              SafeArea(
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _anim,
                    curve: const Interval(0, 0.7, curve: Curves.easeOut),
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AuthRoundIcon(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.maybePop(context),
                            ),
                            const Spacer(),
                            const AuthBrand(),
                          ],
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Create your\nMoonlight account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Stream, connect and earn from what you love.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 26),

                        // Google first — the fastest path.
                        AuthGoogleButton(
                          loading: googleLoading,
                          onTap: busy ? null : _google,
                        ),
                        const SizedBox(height: 20),
                        const AuthOrDivider(label: 'or sign up with email'),
                        const SizedBox(height: 20),

                        AuthGlass(
                          child: Column(
                            children: [
                              AuthField(
                                controller: _email,
                                label: 'Email',
                                icon: Icons.mail_outline_rounded,
                                keyboard: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),
                              AuthField(
                                controller: _name,
                                label: 'Agent name (optional)',
                                icon: Icons.person_outline_rounded,
                                keyboard: TextInputType.name,
                                capitalize: TextCapitalization.words,
                              ),
                              const SizedBox(height: 14),
                              AuthField(
                                controller: _password,
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                password: true,
                              ),
                              AuthStrengthBar(level: _strength),
                              const SizedBox(height: 14),
                              AuthField(
                                controller: _confirm,
                                label: 'Confirm password',
                                icon: Icons.lock_reset_rounded,
                                password: true,
                                last: true,
                              ),
                              const SizedBox(height: 18),
                              AuthPrimaryButton(
                                label: 'Create account',
                                loading: emailLoading,
                                onTap: busy ? null : _submitEmail,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              RouteNames.login,
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14.5,
                                ),
                                children: const [
                                  TextSpan(text: 'Already have an account?  '),
                                  TextSpan(
                                    text: 'Sign in',
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
                        const SizedBox(height: 16),
                        const Center(child: TermsAndPolicyText()),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
