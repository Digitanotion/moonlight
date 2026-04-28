// lib/features/onboarding/presentation/pages/splash_screen.dart
//
// Behaviour:
//   - Appears instantly (no await before runApp)
//   - Stays visible until ALL of:
//       1. DependencyManager ready (all GetIt registrations done)
//       2. Auth bloc resolved (authenticated or unauthenticated)
//       3. Onboarding bloc resolved (isFirstLaunch known)
//       4. Minimum 1.5 s display time (prevents flash)
//   - If network is down or registration fails, still navigates using
//     whatever was resolved from disk cache (never hangs indefinitely)
//   - 12-second hard safety timeout as absolute last resort

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;

  // ── Four gates — ALL must be true before navigation ─────────────────────────
  bool _depsReady = false; // GetIt Track 2 complete
  bool _authDone = false; // AuthBloc emitted a terminal state
  bool _onboardDone = false; // OnboardingBloc resolved isFirstLaunch
  bool _minTimeDone = false; // minimum splash display time elapsed

  bool _navigated = false;

  Timer? _minTimer;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _anim.forward();

    // Minimum display time (prevents splash flash on fast devices)
    _minTimer = Timer(const Duration(milliseconds: 1500), () {
      _minTimeDone = true;
      _tryNavigate();
    });

    // Hard safety valve — if anything hangs, unblock after 12 s
    _safetyTimer = Timer(const Duration(seconds: 12), () {
      debugPrint('🚨 [Splash] Safety timeout — forcing navigation');
      _navigateNow(force: true);
    });

    // Gate 1: wait for all GetIt registrations
    DependencyManager.waitForAllDependencies()
        .then((_) {
          debugPrint('✅ [Splash] GetIt dependencies ready');
          _depsReady = true;

          // Now that deps are ready, fire auth + onboarding checks
          // (they may already be running if the bloc was created earlier)
          if (mounted) {
            context.read<AuthBloc>().add(CheckAuthStatusEvent());
            context.read<OnboardingBloc>().add(const CheckFirstLaunchStatus());
          }
          _tryNavigate();
        })
        .catchError((e) {
          // Dependency init had an error — still unblock so app doesn't hang
          debugPrint('⚠️ [Splash] Dependency error (continuing): $e');
          _depsReady = true;
          if (mounted) {
            context.read<AuthBloc>().add(CheckAuthStatusEvent());
            context.read<OnboardingBloc>().add(const CheckFirstLaunchStatus());
          }
          _tryNavigate();
        });

    // Check if blocs already have resolved states from a previous run
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBlocStates());
  }

  void _checkBlocStates() {
    if (!mounted) return;
    final auth = context.read<AuthBloc>().state;
    final ob = context.read<OnboardingBloc>().state;
    if (auth is AuthAuthenticated || auth is AuthUnauthenticated) {
      _authDone = true;
    }
    if (ob.isFirstLaunch != null) _onboardDone = true;
    _tryNavigate();
  }

  void _tryNavigate() {
    if (_navigated) return;

    final ready = _depsReady && _authDone && _onboardDone && _minTimeDone;

    debugPrint(
      '🔍 [Splash] Gates — deps:$_depsReady auth:$_authDone '
      'onboard:$_onboardDone minTime:$_minTimeDone → ${ready ? "GO" : "WAIT"}',
    );

    if (ready) _navigateNow(force: false);
  }

  void _navigateNow({required bool force}) {
    if (_navigated && !force) return;
    _navigated = true;
    _minTimer?.cancel();
    _safetyTimer?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final auth = context.read<AuthBloc>().state;
        final ob = context.read<OnboardingBloc>().state;
        final firstLaunch = ob.isFirstLaunch;
        final doneProfile = ob.hasCompletedProfile;

        final String route;
        if (firstLaunch == true) {
          route = RouteNames.onboarding;
        } else if (auth is AuthAuthenticated) {
          route = doneProfile == true
              ? RouteNames.home
              : RouteNames.profile_setup;
        } else {
          route = RouteNames.login;
        }

        debugPrint('🚀 [Splash] → $route');
        Navigator.of(context).pushReplacementNamed(route);
      } catch (e) {
        debugPrint('❌ [Splash] Navigation error: $e — falling back to login');
        Navigator.of(context).pushReplacementNamed(RouteNames.login);
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _minTimer?.cancel();
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (_, state) {
            if (state is AuthAuthenticated || state is AuthUnauthenticated) {
              _authDone = true;
              _tryNavigate();
            }
          },
        ),
        BlocListener<OnboardingBloc, OnboardingState>(
          listener: (_, state) {
            if (state.isFirstLaunch != null) {
              _onboardDone = true;
              _tryNavigate();
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AssetPaths.logo,
                  width: 150,
                  height: 150,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Moonlight',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
