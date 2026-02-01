// lib/features/onboarding/presentation/pages/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/app_router.dart';
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

    // Step 1: Show UI immediately (no delay)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _showUI = true;
      });

      // Step 2: Start minimal timer (2 seconds minimum)
      _minimalTimer = Timer(const Duration(milliseconds: 2000), () {
        setState(() {
          _minimalTimePassed = true;
        });
        _tryNavigation();
      });

      // Step 3: Start background loading immediately
      _startBackgroundLoading();

      // Step 4: Trigger quick auth check (non-blocking)
      _triggerQuickAuthCheck();
    });
  }

  void _startBackgroundLoading() {
    // Start loading dependencies in background
    Future(() async {
      try {
        // This runs in background, doesn't block UI
        await SplashOptimizer.loadRemainingDependencies();
        debugPrint('✅ Background dependencies loaded');
      } catch (e) {
        debugPrint('⚠️ Background loading error: $e (non-critical)');
      }
    });
  }

  void _triggerQuickAuthCheck() {
    // Trigger auth check without waiting for it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authBloc = context.read<AuthBloc>();
      final onboardingBloc = context.read<OnboardingBloc>();

      // Trigger auth check (fire and forget)
      authBloc.add(CheckAuthStatusEvent());

      // Trigger onboarding check (fire and forget)
      onboardingBloc.add(const CheckFirstLaunchStatus());

      // Set a loading timer to navigate even if checks take too long
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

    // Check if we have enough info to navigate
    final authState = context.read<AuthBloc>().state;
    final onboardingState = context.read<OnboardingBloc>().state;

    // If we have auth state, navigate
    if (authState is AuthAuthenticated || authState is AuthUnauthenticated) {
      if (onboardingState.isFirstLaunch != null) {
        _navigateToAppropriateScreen();
      } else {
        // Onboarding state not ready yet, wait a bit more
        Future.delayed(const Duration(milliseconds: 500), _tryNavigation);
      }
    } else {
      // Auth state not ready yet, wait a bit more
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
        final isFirstLaunch = onboardingState.isFirstLaunch ?? true;

        debugPrint('🚀 Navigating from splash:');
        debugPrint('   - Auth state: ${authState.runtimeType}');
        debugPrint('   - First launch: $isFirstLaunch');

        if (isFirstLaunch) {
          Navigator.pushReplacementNamed(context, RouteNames.onboarding);
        } else if (authState is AuthAuthenticated) {
          // Go directly to home - services will load in background
          Navigator.pushReplacementNamed(context, RouteNames.home);
        } else {
          Navigator.pushReplacementNamed(context, RouteNames.register);
        }
      } catch (e) {
        debugPrint('❌ Navigation error: $e');
        // Fallback
        Navigator.pushReplacementNamed(context, RouteNames.register);
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
              // Logo
              Image.asset(
                AssetPaths.logo,
                width: 150,
                height: 150,
                filterQuality: FilterQuality.high,
              ),

              const SizedBox(height: 32),

              // Subtle loading indicator (only shows after 1 second)
              if (!_minimalTimePassed)
                _buildLoadingIndicator()
              else
                _buildReadyIndicator(),

              const SizedBox(height: 24),

              // App name
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
      child: Icon(Icons.check, color: Colors.white, size: 20),
    );
  }
}
