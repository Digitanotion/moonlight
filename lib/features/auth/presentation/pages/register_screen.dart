// lib/features/auth/presentation/pages/register_screen.dart
//
// Sign-up: Google or email. A pending agent invite code (from an invite
// link, or typed here) is saved before either path so the account is
// attached to that agent on first login — see PendingAgentCodeService.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/pending_agent_code_service.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/core/widgets/app_logo_loader.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/widgets/terms_and_policy.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:moonlight/widgets/moon_snack.dart';

const _kBgTop = Color(0xFF0B1240);
const _kBgBottom = Color(0xFF05071A);
const _kAccent = Color(0xFFFF6A00);
const _kAccentSoft = Color(0xFFFF9A4D);

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
  final _agentCode = TextEditingController();

  late final AnimationController _anim;
  bool _showCodeField = false;
  bool _invitedByLink = false;
  bool _resolvingPostLogin = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _password.addListener(() => setState(() {}));
    PendingAgentCodeService.peek().then((c) {
      if (c != null && mounted) {
        setState(() {
          _agentCode.text = c;
          _showCodeField = true;
          _invitedByLink = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    _agentCode.dispose();
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
    PendingAgentCodeService.save(_agentCode.text);
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
    PendingAgentCodeService.save(_agentCode.text);
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
          backgroundColor: _kBgBottom,
          body: Stack(
            children: [
              const _Backdrop(),
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
                            _RoundIcon(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.maybePop(context),
                            ),
                            const Spacer(),
                            const _Brand(),
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
                        if (_invitedByLink) ...[
                          const SizedBox(height: 20),
                          const _InviteBadge(),
                        ],
                        const SizedBox(height: 26),

                        // Google first — the fastest path.
                        _GoogleButton(
                          loading: googleLoading,
                          onTap: busy ? null : _google,
                        ),
                        const SizedBox(height: 20),
                        const _OrDivider(label: 'or sign up with email'),
                        const SizedBox(height: 20),

                        _Glass(
                          child: Column(
                            children: [
                              _Field(
                                controller: _email,
                                label: 'Email',
                                icon: Icons.mail_outline_rounded,
                                keyboard: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),
                              _Field(
                                controller: _name,
                                label: 'Display name (optional)',
                                icon: Icons.person_outline_rounded,
                                keyboard: TextInputType.name,
                                capitalize: TextCapitalization.words,
                              ),
                              const SizedBox(height: 14),
                              _Field(
                                controller: _password,
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                password: true,
                              ),
                              _StrengthBar(level: _strength),
                              const SizedBox(height: 14),
                              _Field(
                                controller: _confirm,
                                label: 'Confirm password',
                                icon: Icons.lock_reset_rounded,
                                password: true,
                                last: !_showCodeField,
                              ),
                              const SizedBox(height: 6),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                alignment: Alignment.topCenter,
                                child: _showCodeField
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: _Field(
                                          controller: _agentCode,
                                          label: 'Agent code',
                                          icon: Icons.groups_2_outlined,
                                          capitalize:
                                              TextCapitalization.characters,
                                          last: true,
                                        ),
                                      )
                                    : Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton.icon(
                                          onPressed: () => setState(
                                            () => _showCodeField = true,
                                          ),
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 18,
                                            color: _kAccentSoft,
                                          ),
                                          label: const Text(
                                            'Have an agent code?',
                                            style: TextStyle(
                                              color: _kAccentSoft,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 18),
                              _PrimaryButton(
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

// ── building blocks ────────────────────────────────────────────────────

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kBgTop, _kBgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -90,
          child: _Orb(size: 320, color: const Color(0xFF3D4DFF)),
        ),
        Positioned(
          bottom: 120,
          left: -140,
          child: _Orb(size: 300, color: _kAccent.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.32), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(colors: [_kAccent, _kAccentSoft]),
          ),
          child: const Icon(
            Icons.nights_stay_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Moonlight',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _InviteBadge extends StatelessWidget {
  const _InviteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _kAccent.withValues(alpha: 0.14),
        border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_rounded, color: _kAccentSoft, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "You've been invited by a Moonlight agent. Your code is applied "
              'automatically once you sign up.',
              style: TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool password;
  final bool last;
  final TextInputType keyboard;
  final TextCapitalization capitalize;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.password = false,
    this.last = false,
    this.keyboard = TextInputType.text,
    this.capitalize = TextCapitalization.none,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.password && _hide,
      keyboardType: widget.password
          ? TextInputType.visiblePassword
          : widget.keyboard,
      textCapitalization: widget.capitalize,
      textInputAction: widget.last
          ? TextInputAction.done
          : TextInputAction.next,
      autocorrect: false,
      cursorColor: _kAccent,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
        floatingLabelStyle: const TextStyle(
          color: _kAccentSoft,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          widget.icon,
          size: 20,
          color: Colors.white.withValues(alpha: 0.6),
        ),
        suffixIcon: widget.password
            ? IconButton(
                splashRadius: 18,
                onPressed: () => setState(() => _hide = !_hide),
                icon: Icon(
                  _hide
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kAccent, width: 1.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final int level; // 0..4
  const _StrengthBar({required this.level});

  @override
  Widget build(BuildContext context) {
    if (level == 0) return const SizedBox(height: 0);
    const labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    final color = [
      Colors.transparent,
      const Color(0xFFEF4444),
      const Color(0xFFF5A623),
      const Color(0xFF7ED957),
      const Color(0xFF1FBF75),
    ][level];
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
      child: Row(
        children: [
          for (var i = 1; i <= 4; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                margin: EdgeInsets.only(right: i == 4 ? 0 : 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i <= level
                      ? color
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
          const SizedBox(width: 10),
          Text(
            labels[level],
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null && !loading ? 0.6 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [_kAccent, _kAccentSoft]),
            boxShadow: [
              BoxShadow(
                color: _kAccent.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: loading
              ? const SizedBox(width: 26, height: 26, child: AppLogoLoader())
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: loading
            ? const Center(
                child: SizedBox(width: 26, height: 26, child: AppLogoLoader()),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    AssetPaths.googleIcon,
                    width: 22,
                    height: 22,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Color(0xFF111322),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  final String label;
  const _OrDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(color: Colors.white.withValues(alpha: 0.16), height: 1),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12.5,
            ),
          ),
        ),
        line,
      ],
    );
  }
}
