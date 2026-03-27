// lib/features/onboarding/presentation/pages/splash_screen.dart
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
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showUI = false;
  bool _minimalTimePassed = false;
  Timer? _minimalTimer;
  Timer? _loadingTimer;
  bool _navigationTriggered = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _showUI = true);

      _minimalTimer = Timer(const Duration(milliseconds: 2000), () {
        setState(() => _minimalTimePassed = true);
        _tryNavigation();
      });

      _startBackgroundLoading();
      _triggerQuickAuthCheck();
    });
  }

  void _startBackgroundLoading() {
    Future(() async {
      try {
        await SplashOptimizer.loadRemainingDependencies();
        debugPrint('✅ Background dependencies loaded');
      } catch (e) {
        debugPrint('⚠️ Background loading error: $e (non-critical)');
      }
    });
  }

  void _triggerQuickAuthCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthBloc>().add(CheckAuthStatusEvent());
      context.read<OnboardingBloc>().add(const CheckFirstLaunchStatus());

      _loadingTimer = Timer(const Duration(milliseconds: 2500), () {
        if (!_navigationTriggered) {
          debugPrint('⏱️ Loading timer expired, forcing navigation');
          _navigateToAppropriateScreen();
        }
      });
    });
  }

  void _tryNavigation() {
    if (!_minimalTimePassed || _navigationTriggered) return;

    final authState = context.read<AuthBloc>().state;
    final onboardingState = context.read<OnboardingBloc>().state;

    if (authState is AuthAuthenticated || authState is AuthUnauthenticated) {
      _navigateToAppropriateScreen();
    } else {
      // Auth state not resolved yet — retry shortly
      Future.delayed(const Duration(milliseconds: 500), _tryNavigation);
    }
  }

  void _navigateToAppropriateScreen() {
    if (_navigationTriggered) return;

    _navigationTriggered = true;
    _minimalTimer?.cancel();
    _loadingTimer?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final authState = context.read<AuthBloc>().state;
        final onboardingState = context.read<OnboardingBloc>().state;
        final isFirstLaunch = onboardingState.isFirstLaunch;
        final hasCompletedProfile = onboardingState.hasCompletedProfile;

        debugPrint('🚀 Navigating from splash:');
        debugPrint('   Auth state     : ${authState.runtimeType}');
        debugPrint('   First launch   : $isFirstLaunch');
        debugPrint('   Profile done   : $hasCompletedProfile');

        if (isFirstLaunch) {
          // Brand-new install — show onboarding slides first.
          Navigator.pushReplacementNamed(context, RouteNames.onboarding);
        } else if (authState is AuthAuthenticated) {
          if (!hasCompletedProfile) {
            // Returning user who skipped profile setup — send them there once.
            Navigator.pushReplacementNamed(context, RouteNames.profile_setup);
          } else {
            // Fully set-up returning user — go straight to home.
            Navigator.pushReplacementNamed(context, RouteNames.home);
          }
        } else {
          // Not authenticated — go to login.
          Navigator.pushReplacementNamed(context, RouteNames.login);
        }
      } catch (e) {
        debugPrint('❌ Navigation error: $e');
        Navigator.pushReplacementNamed(context, RouteNames.login);
      }
    });
  }

  @override
  void dispose() {
    _minimalTimer?.cancel();
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: AnimatedOpacity(
        opacity: _showUI ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
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
              Text(
                'Moonlight',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      // bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLoadingIndicator(),
          const SizedBox(width: 16),
          _buildReadyIndicator(),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildReadyIndicator() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 20),
    );
  }
}
