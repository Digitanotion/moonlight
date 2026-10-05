// lib/features/auth/presentation/pages/email_verification.dart
//
// Email verification by 6-digit code (sent right after sign-up, or when an
// unverified account tries to sign in). One hidden text field backs the six
// boxes so typing, paste and the keyboard's one-time-code suggestion all
// work; the code submits itself on the sixth digit.

import 'dart:async';

import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/core/services/pending_agent_code_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_ui.dart';
import 'package:moonlight/widgets/moon_snack.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  /// Held in memory only (never stored) so the user can be signed in
  /// automatically right after verifying. Null → fall back to Sign In.
  final String? password;
  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.password,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const _len = 6;

  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _resendIn = 45;
  bool _verifying = false;
  bool _resending = false;
  bool _verified = false;
  bool _signingIn = false;
  bool _routing = false;
  String? _error;

  Dio get _dio => sl<Dio>(instanceName: 'mainDio');

  @override
  void initState() {
    super.initState();
    _startTimer(45);
    _code.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _masked {
    final parts = widget.email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return widget.email;
    final local = parts[0];
    return '${local[0]}${'•' * (local.length > 2 ? 3 : 1)}@${parts[1]}';
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendIn <= 1) {
        t.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn--);
      }
    });
  }

  void _onChanged() {
    if (_error != null) setState(() => _error = null);
    setState(() {});
    if (_code.text.length == _len && !_verifying && !_verified) _verify();
  }

  String _serverMessage(Object e, String fallback) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) return d['message'].toString();
    }
    return fallback;
  }

  Future<void> _verify() async {
    if (_code.text.length != _len) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await _dio.post(
        '/api/v1/email/verify-code',
        data: {'email': widget.email, 'code': _code.text},
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _verified = true);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final pw = widget.password;
      if (pw == null || pw.isEmpty) {
        _toLogin();
        return;
      }
      // Sign in straight away so they continue into profile setup.
      setState(() => _signingIn = true);
      context.read<AuthBloc>().add(
        LoginWithEmailRequested(email: widget.email, password: pw),
      );
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      _code.clear();
      setState(() {
        _error = _serverMessage(e, 'Could not verify. Check your connection.');
      });
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _toLogin() {
    Navigator.pushNamedAndRemoveUntil(context, RouteNames.login, (_) => false);
    MoonSnack.success(context, 'Email verified! Sign in to continue.');
  }

  /// Same live profile-completion check the login screen runs.
  Future<void> _continueAfterSignIn() async {
    if (_routing) return;
    _routing = true;
    PendingAgentCodeService.applyIfPending();
    final onboarding = context.read<OnboardingBloc>();
    final next = onboarding.stream.first;
    onboarding.add(const CheckFirstLaunchStatus());
    final updated = await next.timeout(
      const Duration(seconds: 4),
      onTimeout: () => onboarding.state,
    );
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      updated.hasCompletedProfile ? RouteNames.home : RouteNames.profile_setup,
      (_) => false,
    );
  }

  Future<void> _resend() async {
    if (_resendIn > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await _dio.post(
        '/api/v1/email/verification-notification',
        data: {'email': widget.email},
      );
      if (!mounted) return;
      _code.clear();
      _startTimer(45);
      MoonSnack.success(context, 'A new code is on its way.');
    } on DioException catch (e) {
      final wait = (e.response?.data is Map)
          ? (e.response!.data['retry_after'] as num?)?.toInt()
          : null;
      if (wait != null && mounted) _startTimer(wait);
      if (mounted) {
        MoonSnack.error(
          context,
          _serverMessage(e, 'Could not resend the code.'),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (!_signingIn) return;
        if (state is AuthAuthenticated) {
          _continueAfterSignIn();
        } else if (state is AuthFailure) {
          // Verified, but the automatic sign-in didn't go through.
          _signingIn = false;
          _toLogin();
        }
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: kAuthBgBottom,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const AuthBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                  const SizedBox(height: 40),
                  const Text(
                    'Verify your\nemail',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      height: 1.06,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 15,
                        height: 1.45,
                      ),
                      children: [
                        const TextSpan(text: 'We sent a 6-digit code to '),
                        TextSpan(
                          text: _masked,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: '. Enter it below — it expires in 15 minutes.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  AuthGlass(
                    child: Column(
                      children: [
                        _codeBoxes(),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: _error == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        size: 16,
                                        color: Color(0xFFFF6B6B),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Color(0xFFFF6B6B),
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 22),
                        AuthPrimaryButton(
                          label: _verified ? 'Verified ✓' : 'Verify email',
                          loading: _verifying || _signingIn,
                          onTap:
                              (_verifying ||
                                  _verified ||
                                  _code.text.length != _len)
                              ? null
                              : _verify,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: _resendIn > 0
                        ? Text(
                            'Resend code in ${_resendIn}s',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 14.5,
                            ),
                          )
                        : TextButton(
                            onPressed: _resending ? null : _resend,
                            child: Text(
                              _resending
                                  ? 'Sending…'
                                  : "Didn't get it? Resend code",
                              style: const TextStyle(
                                color: kAuthAccentSoft,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Check your spam folder if you don’t see it.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        RouteNames.login,
                        (_) => false,
                      ),
                      child: Text(
                        'Back to sign in',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBoxes() {
    final text = _code.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_len, (i) {
              final filled = i < text.length;
              final active = i == text.length && _focus.hasFocus;
              final bad = _error != null;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 46,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: filled ? 0.12 : 0.06),
                  border: Border.all(
                    color: _verified
                        ? const Color(0xFF1FBF75)
                        : bad
                        ? const Color(0xFFFF6B6B)
                        : active
                        ? kAuthAccent
                        : Colors.white.withValues(alpha: 0.12),
                    width: active || _verified ? 1.8 : 1.2,
                  ),
                ),
                child: Text(
                  filled ? text[i] : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }),
          ),
          // The real input: invisible, sits over the boxes so a tap focuses
          // it; supports paste and the keyboard's code autofill.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _code,
                focusNode: _focus,
                autofillHints: const [AutofillHints.oneTimeCode],
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: _len,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
