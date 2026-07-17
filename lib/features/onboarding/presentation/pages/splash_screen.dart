// lib/features/onboarding/presentation/pages/splash_screen.dart
//
// Behaviour:
//   - Appears instantly (no await before runApp)
//   - Stays visible until ALL of:
//       1. DependencyManager ready (all GetIt registrations done)
//       2. Auth bloc resolved (authenticated or unauthenticated)
//       3. OnboardingBloc's AUTHORITATIVE check resolved — profileCheckResolved,
//          not merely isFirstLaunch != null (see onboarding_state.dart for why
//          that distinction matters: LoadOnboardingStatus sets isFirstLaunch
//          using a stale cached value well before the live profile check
//          even starts, and gating on isFirstLaunch alone let Splash
//          navigate on that stale value before the live check could correct it)
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

  bool _depsReady = false;
  bool _authDone = false;
  bool _onboardDone = false;
  bool _minTimeDone = false;

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

    _minTimer = Timer(const Duration(milliseconds: 1500), () {
      _minTimeDone = true;
      _tryNavigate();
    });

    _safetyTimer = Timer(const Duration(seconds: 12), () {
      debugPrint('🚨 [Splash] Safety timeout — forcing navigation');
      _navigateNow(force: true);
    });

    DependencyManager.waitForAllDependencies()
        .then((_) {
          debugPrint('✅ [Splash] GetIt dependencies ready');
          _depsReady = true;
          if (mounted) {
            context.read<AuthBloc>().add(CheckAuthStatusEvent());
            context.read<OnboardingBloc>().add(const CheckFirstLaunchStatus());
          }
          _tryNavigate();
        })
        .catchError((e) {
          debugPrint('⚠️ [Splash] Dependency error (continuing): $e');
          _depsReady = true;
          if (mounted) {
            context.read<AuthBloc>().add(CheckAuthStatusEvent());
            context.read<OnboardingBloc>().add(const CheckFirstLaunchStatus());
          }
          _tryNavigate();
        });

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBlocStates());
  }

  void _checkBlocStates() {
    if (!mounted) return;
    final auth = context.read<AuthBloc>().state;
    final ob = context.read<OnboardingBloc>().state;
    if (auth is AuthAuthenticated || auth is AuthUnauthenticated) {
      _authDone = true;
    }
    // Gate on the AUTHORITATIVE check having resolved, not merely on
    // isFirstLaunch being non-null — see the header comment above.
    if (ob.profileCheckResolved) _onboardDone = true;
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
            // Gate on the AUTHORITATIVE check having resolved, not
            // merely on isFirstLaunch being non-null. LoadOnboardingStatus
            // (fired 100ms after bloc creation) sets isFirstLaunch using
            // a stale cached hasCompletedProfile value, well before the
            // live check via CheckFirstLaunchStatus even starts — gating
            // on isFirstLaunch alone let this fire early and lock in a
            // stale routing decision that the live check would have
            // corrected a moment later.
            if (state.profileCheckResolved) {
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