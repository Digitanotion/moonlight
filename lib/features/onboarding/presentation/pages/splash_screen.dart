// lib/features/onboarding/presentation/pages/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool _minimalTimePassed = false;
  bool _navigationTriggered = false;
  Timer? _minimalTimer;
  Timer? _safetyTimer;

  // Debug counters
  int _tryNavigationCallCount = 0;
  int _authStateChanges = 0;
  int _onboardingStateChanges = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('🎬 [Splash] initState called');

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('📞 [Splash] Post-frame callback - firing events');

      // Fire events
      context.read<AuthBloc>().add(CheckAuthStatusEvent());
      context.read<OnboardingBloc>().add(const CheckFirstLaunchStatus());

      // Check current states immediately
      _checkCurrentStates();

      // Set timers
      _minimalTimer = Timer(const Duration(milliseconds: 1800), () {
        debugPrint('⏰ [Splash] Minimal timer (1800ms) FIRED');
        _minimalTimePassed = true;
        _tryNavigation(reason: 'minimal_timer');
      });

      _safetyTimer = Timer(const Duration(milliseconds: 10000), () {
        if (!_navigationTriggered) {
          debugPrint(
            '🚨 [Splash] SAFETY TIMER FIRED - forcing navigation after 10 seconds',
          );
          _navigateToAppropriateScreen(force: true);
        }
      });
    });
  }

  void _checkCurrentStates() {
    debugPrint('🔍 [Splash] Checking current states');

    final authState = context.read<AuthBloc>().state;
    final onboardingState = context.read<OnboardingBloc>().state;

    debugPrint('   Current AuthState: ${authState.runtimeType}');
    debugPrint('   Current OnboardingState: ${onboardingState.runtimeType}');
    debugPrint(
      '   onboardingState.isFirstLaunch: ${onboardingState.isFirstLaunch}',
    );
    debugPrint(
      '   onboardingState.hasCompletedProfile: ${onboardingState.hasCompletedProfile}',
    );

    final authResolved =
        authState is AuthAuthenticated || authState is AuthUnauthenticated;
    final onboardingResolved = onboardingState.isFirstLaunch != null;

    debugPrint('   authResolved: $authResolved');
    debugPrint('   onboardingResolved: $onboardingResolved');

    if (authResolved && onboardingResolved) {
      debugPrint('✅ States already resolved - will try navigation');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryNavigation(reason: 'initial_check');
      });
    } else {
      debugPrint('⏳ States not yet resolved - waiting for BLoC listeners');
    }
  }

  void _tryNavigation({required String reason}) {
    _tryNavigationCallCount++;
    debugPrint(
      '🔁 [_tryNavigation #$_tryNavigationCallCount] Called from: $reason',
    );
    debugPrint('   _navigationTriggered: $_navigationTriggered');
    debugPrint('   _minimalTimePassed: $_minimalTimePassed');

    if (_navigationTriggered) {
      debugPrint('   ⏭️ Navigation already triggered, skipping');
      return;
    }

    if (!_minimalTimePassed) {
      debugPrint('   ⏳ Minimal time not passed yet, waiting...');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    final onboardingState = context.read<OnboardingBloc>().state;

    debugPrint('   Current AuthState: ${authState.runtimeType}');
    debugPrint('   Current OnboardingState: ${onboardingState.runtimeType}');
    debugPrint(
      '   onboardingState.isFirstLaunch: ${onboardingState.isFirstLaunch}',
    );

    final authResolved =
        authState is AuthAuthenticated || authState is AuthUnauthenticated;
    final onboardingResolved = onboardingState.isFirstLaunch != null;

    debugPrint('   authResolved: $authResolved');
    debugPrint('   onboardingResolved: $onboardingResolved');

    if (authResolved && onboardingResolved) {
      debugPrint('✅ ALL CONDITIONS MET - navigating!');
      _navigateToAppropriateScreen(force: false);
    } else {
      debugPrint('❌ CONDITIONS NOT MET - waiting for BLoC updates');
      debugPrint(
        '   Missing: ${!authResolved ? "Auth" : ""} ${!onboardingResolved ? "Onboarding" : ""}',
      );
    }
  }

  void _navigateToAppropriateScreen({required bool force}) {
    if (_navigationTriggered && !force) {
      debugPrint('   Navigation already triggered, skipping');
      return;
    }

    debugPrint('🚀 [_navigateToAppropriateScreen] force=$force');
    _navigationTriggered = true;

    _minimalTimer?.cancel();
    _safetyTimer?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        debugPrint('   Widget not mounted, cannot navigate');
        return;
      }

      try {
        final authState = context.read<AuthBloc>().state;
        final onboardingState = context.read<OnboardingBloc>().state;
        final isFirstLaunch = onboardingState.isFirstLaunch;
        final hasCompletedProfile = onboardingState.hasCompletedProfile;

        debugPrint('📊 Final state for navigation:');
        debugPrint('   auth: ${authState.runtimeType}');
        debugPrint('   isFirstLaunch: $isFirstLaunch');
        debugPrint('   hasCompletedProfile: $hasCompletedProfile');

        String route;
        if (isFirstLaunch == true) {
          route = RouteNames.onboarding;
        } else if (authState is AuthAuthenticated) {
          route = hasCompletedProfile == true
              ? RouteNames.home
              : RouteNames.profile_setup;
        } else {
          route = RouteNames.login;
        }

        debugPrint('➡️ Navigating to: $route');
        Navigator.pushReplacementNamed(context, route);
      } catch (e, stack) {
        debugPrint('❌ Navigation error: $e');
        debugPrint('Stack trace: $stack');
        Navigator.pushReplacementNamed(context, RouteNames.login);
      }
    });
  }

  @override
  void dispose() {
    debugPrint('🧹 [Splash] dispose called');
    _animController.dispose();
    _minimalTimer?.cancel();
    _safetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ [Splash] build called');

    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            _authStateChanges++;
            debugPrint(
              '🔔 [AuthBloc] State changed #$_authStateChanges: ${state.runtimeType}',
            );
            if (state is AuthAuthenticated || state is AuthUnauthenticated) {
              debugPrint('   ✅ Auth resolved!');
              _tryNavigation(reason: 'auth_listener');
            }
          },
        ),
        BlocListener<OnboardingBloc, OnboardingState>(
          listener: (context, state) {
            _onboardingStateChanges++;
            debugPrint(
              '🔔 [OnboardingBloc] State changed #$_onboardingStateChanges:',
            );
            debugPrint('   isFirstLaunch: ${state.isFirstLaunch}');
            debugPrint('   hasCompletedProfile: ${state.hasCompletedProfile}');
            if (state.isFirstLaunch != null) {
              debugPrint('   ✅ Onboarding resolved!');
              _tryNavigation(reason: 'onboarding_listener');
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: FadeTransition(
          opacity: _fadeAnim,
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
                // Add a loading indicator for debugging
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
