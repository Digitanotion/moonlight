import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/app_router.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/core/services/service_registration_manager.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/pages/service_registration_screen.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Track loading progress
  double _loadingProgress = 0.0;
  bool _isInitialized = false;
  StreamController<double>? _progressController;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // Start animations
    _controller.forward();

    // Start loading process
    _startLoadingProcess();
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController?.close();
    super.dispose();
  }

  Future<void> _startLoadingProcess() async {
    try {
      // Create a stream for progress updates
      _progressController = StreamController<double>();

      // Step 1: Immediate UI feedback (0-15%)
      _updateProgress(0.15);
      await Future.delayed(const Duration(milliseconds: 100));

      // Step 2: Load essential services with priority
      // ✅ Onboarding check first (it's faster)
      await _loadOnboardingStatus();
      _updateProgress(0.4);

      // ✅ Then auth check
      await _loadAuthStatus();
      _updateProgress(0.7);

      // Step 3: Trigger background loading (don't wait for it)
      _triggerBackgroundLoading();
      _updateProgress(0.85);

      // Step 4: Final delay for smooth transition
      await Future.delayed(const Duration(milliseconds: 300));
      _updateProgress(1.0);

      // Mark as initialized
      _isInitialized = true;

      // Navigate
      _navigateWithServiceRegistration();
    } catch (e, stack) {
      debugPrint('❌ Critical error in loading process: $e');
      debugPrint('Stack: $stack');

      // Emergency navigation on error
      if (mounted) {
        _updateProgress(1.0);
        _isInitialized = true;
        Navigator.pushReplacementNamed(context, RouteNames.register);
      }
    }
  }

  Future<void> _loadOnboardingStatus() async {
    try {
      // Get the onboarding bloc
      final onboardingBloc = _safeReadBloc<OnboardingBloc>(context);

      // FIRST: Add a small delay to ensure BLoC is fully ready
      await Future.delayed(const Duration(milliseconds: 100));

      // Check current state first - it might already have the value
      final currentState = onboardingBloc.state;
      if (currentState.isFirstLaunch != null) {
        debugPrint(
          '✅ Onboarding status already available: ${currentState.isFirstLaunch}',
        );
        return;
      }

      // ✅ FIXED: Use the new event specifically for splash
      onboardingBloc.add(const CheckFirstLaunchStatus());

      // Wait for state change with timeout
      final completer = Completer<void>();
      final timeoutDuration = const Duration(seconds: 2); // Reduced timeout
      final startTime = DateTime.now();

      // Listen for state changes
      final subscription = onboardingBloc.stream.listen((state) {
        if (state.isFirstLaunch != null) {
          if (!completer.isCompleted) {
            debugPrint('✅ Splash got onboarding state: ${state.isFirstLaunch}');
            completer.complete();
          }
        }

        // Check for timeout
        if (DateTime.now().difference(startTime) > timeoutDuration) {
          if (!completer.isCompleted) {
            debugPrint(
              '⚠️ Splash onboarding check timeout, using default (true)',
            );
            completer.complete();
          }
        }
      });

      // Wait for completion or timeout
      await completer.future;
      await Future.delayed(const Duration(milliseconds: 50)); // Small buffer
      subscription.cancel();
    } catch (e, stack) {
      debugPrint('⚠️ Splash onboarding check error: $e');
      debugPrint('Stack: $stack');
      // Continue anyway - default to first launch
    }
  }

  Future<void> _loadAuthStatus() async {
    try {
      final authBloc = _safeReadBloc<AuthBloc>(context);

      // Check current state first
      final currentState = authBloc.state;
      if (currentState is AuthAuthenticated ||
          currentState is AuthUnauthenticated) {
        debugPrint(
          '✅ Auth status already available: ${currentState.runtimeType}',
        );
        return;
      }

      // Trigger auth check
      authBloc.add(CheckAuthStatusEvent());

      // Wait for auth state with timeout using completer pattern
      final completer = Completer<void>();
      final timeoutDuration = const Duration(seconds: 3);
      final startTime = DateTime.now();

      final subscription = authBloc.stream.listen((state) {
        if (state is AuthAuthenticated || state is AuthUnauthenticated) {
          if (!completer.isCompleted) {
            debugPrint('✅ Got auth state: ${state.runtimeType}');
            completer.complete();
          }
        }

        // Check for timeout
        if (DateTime.now().difference(startTime) > timeoutDuration) {
          if (!completer.isCompleted) {
            debugPrint('⚠️ Auth check timeout, assuming unauthenticated');
            completer.complete();
          }
        }
      });

      await completer.future;
      subscription.cancel();
    } catch (e) {
      debugPrint('⚠️ Auth check error: $e');
      // Continue anyway - the app will handle unauthenticated state
    }
  }

  /// Safely reads a BLoC with error handling
  T _safeReadBloc<T>(BuildContext context) {
    try {
      return context.read<T>();
    } catch (e) {
      debugPrint('⚠️ Error reading BLoC of type $T: $e');
      // Re-throw to fail fast in development
      rethrow;
    }
  }

  void _triggerBackgroundLoading() {
    // Load heavy services in background without waiting
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Check if GetIt is ready (using safe check)
      try {
        // Try to access the service to see if it's registered
        final _ = GetIt.I<PusherService>();
        // If we get here, it's registered (but may not be initialized)

        // Initialize non-critical services after app starts
        await Future.delayed(const Duration(milliseconds: 500));

        // These will initialize lazily when first accessed
        debugPrint('🚀 Background service initialization started');

        // Force lazy initialization of heavy services
        final pusher = GetIt.I<PusherService>(); // Will trigger lazy init
        debugPrint('✅ Pusher service accessed: ${pusher.runtimeType}');

        // Other heavy services can be loaded here if needed
        debugPrint('✅ Background services initialized');
      } catch (e) {
        debugPrint('⚠️ Background service init failed: $e');
        // Don't crash - these are non-critical for splash
      }
    });
  }

  void _updateProgress(double progress) {
    if (_progressController != null && !_progressController!.isClosed) {
      _progressController!.add(progress);
    }

    setState(() {
      _loadingProgress = progress;
    });
  }

  Future<void> _navigateToNextScreen() async {
    // Small delay for smooth animation completion
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    try {
      // Get onboarding status
      final onboardingState = context.read<OnboardingBloc>().state;
      final isFirstLaunch = onboardingState.isFirstLaunch ?? true;

      // Get auth status
      final authState = context.read<AuthBloc>().state;

      // For debugging
      final prefs = await SharedPreferences.getInstance();
      debugPrint('Splash debug:');
      debugPrint('  - isFirstLaunch: $isFirstLaunch');
      debugPrint('  - authState: ${authState.runtimeType}');
      debugPrint('  - hasToken: ${prefs.getString('auth_token') != null}');
      debugPrint(
        '  - onboardingComplete: ${prefs.getBool('hasCompletedOnboarding')}',
      );

      // Navigation logic
      if (isFirstLaunch) {
        Navigator.pushReplacementNamed(context, RouteNames.onboarding);
      } else if (authState is AuthAuthenticated) {
        Navigator.pushReplacementNamed(context, RouteNames.home);
      } else {
        Navigator.pushReplacementNamed(context, RouteNames.register);
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      // Fallback navigation
      Navigator.pushReplacementNamed(context, RouteNames.register);
    }
  }

  Future<void> _navigateWithServiceRegistration() async {
    if (!mounted) return;

    try {
      // Get onboarding status
      final onboardingState = context.read<OnboardingBloc>().state;
      final isFirstLaunch = onboardingState.isFirstLaunch ?? true;

      // Get auth status
      final authState = context.read<AuthBloc>().state;

      // Navigation logic
      if (isFirstLaunch) {
        Navigator.pushReplacementNamed(context, RouteNames.onboarding);
      } else if (authState is AuthAuthenticated) {
        // CRITICAL CHANGE: Check service registration status FIRST
        final manager = ServiceRegistrationManager();
        final areServicesRegistered = manager.isRegistered;

        debugPrint('🔍 Service registration status: $areServicesRegistered');

        if (areServicesRegistered) {
          // Services already registered, go directly to home
          debugPrint('✅ Services already registered, going directly to home');
          Navigator.pushReplacementNamed(context, RouteNames.home);
        } else {
          // Services not registered, show registration screen
          debugPrint('🔄 Services not registered, showing registration screen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceRegistrationScreen(
                onSuccess: () {
                  debugPrint(
                    '✅ Service registration successful, navigating to home',
                  );
                  Navigator.pushReplacementNamed(context, RouteNames.home);
                },
                onSkip: () {
                  debugPrint('⚠️ User chose to skip service registration');

                  // DON'T navigate to home immediately
                  // Instead, show a warning screen or go to home with disabled features
                  _navigateToHomeWithDisabledFeatures();
                },
              ),
            ),
          );
        }
      } else {
        Navigator.pushReplacementNamed(context, RouteNames.register);
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      // Fallback: go to registration
      Navigator.pushReplacementNamed(context, RouteNames.register);
    }
  }

  // Add this new method
  void _navigateToHomeWithDisabledFeatures() {
    // You can either:
    // 1. Navigate to home with a flag indicating features are disabled
    // 2. Navigate to a warning screen first
    // 3. Use a different route that shows features are disabled

    // For option 1 (navigate with flag):
    Navigator.pushReplacementNamed(
      context,
      RouteNames.home,
      arguments: {'realTimeFeaturesDisabled': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with pulsing animation
                    _buildAnimatedLogo(),
                    const SizedBox(height: 40),

                    // Modern progress indicator
                    _buildProgressIndicator(),

                    // Optional: Loading text with dots animation
                    if (!_isInitialized) _buildLoadingText(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Logo
          Center(
            child: Image.asset(
              AssetPaths.logo,
              width: 120,
              height: 120,
              filterQuality: FilterQuality.high,
            ),
          ),

          // Pulsing ring effect
          if (!_isInitialized)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _PulsePainter(
                      progress: _controller.value,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return SizedBox(
      width: 200,
      child: Column(
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _loadingProgress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.8),
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 12),

          // Percentage text
          Text(
            '${(_loadingProgress * 100).toInt()}%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingText() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: _LoadingDotsWidget(),
    );
  }
}

class _LoadingDotsWidget extends StatefulWidget {
  @override
  _LoadingDotsWidgetState createState() => _LoadingDotsWidgetState();
}

class _LoadingDotsWidgetState extends State<_LoadingDotsWidget> {
  int _dotCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _dotCount = (_dotCount + 1) % 4; // Cycle 0, 1, 2, 3
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    return Text(
      'Loading$dots',
      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
    );
  }
}

// Custom painter for pulse animation
class _PulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulsePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 1.5;

    // Create pulse effect
    final pulseProgress = (progress * 2) % 1.0;
    final radius = maxRadius * pulseProgress;
    final opacity = 1.0 - pulseProgress;

    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
