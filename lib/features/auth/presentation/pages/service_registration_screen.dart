import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:moonlight/core/services/service_registration_manager.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_theme.dart';

class ServiceRegistrationScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onSkip;

  const ServiceRegistrationScreen({
    super.key,
    required this.onSuccess,
    required this.onSkip,
  });

  @override
  State<ServiceRegistrationScreen> createState() =>
      _ServiceRegistrationScreenState();
}

class _ServiceRegistrationScreenState extends State<ServiceRegistrationScreen>
    with TickerProviderStateMixin {
  final ServiceRegistrationManager _manager = ServiceRegistrationManager();
  bool _isLoading = true;
  String? _errorMessage;
  int _retryCount = 0;
  Timer? _timeoutTimer;
  bool _hasCompleted = false;
  bool _shouldSkip = false;

  // Animation controllers
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _wifiBarsController;
  late AnimationController _successController;

  // Animations
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _wifiBar1Animation;
  late Animation<double> _wifiBar2Animation;
  late Animation<double> _wifiBar3Animation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize main animation controller
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Initialize wifi bars animation
    _wifiBarsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // Initialize success animation (will be started on success)
    _successController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Setup animations
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.linear));

    // WiFi bars animations (staggered)
    _wifiBar1Animation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _wifiBarsController, curve: Curves.easeInOut),
        );

    _wifiBar2Animation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 0.3),
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 0.3),
        ]).animate(
          CurvedAnimation(parent: _wifiBarsController, curve: Curves.easeInOut),
        );

    _wifiBar3Animation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 0.6),
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 0.6),
        ]).animate(
          CurvedAnimation(parent: _wifiBarsController, curve: Curves.easeInOut),
        );

    _colorAnimation =
        ColorTween(
          begin: AppColors.primary.withOpacity(0.7),
          end: AppColors.primary,
        ).animate(
          CurvedAnimation(parent: _mainController, curve: Curves.easeInOut),
        );

    _registerServices();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _mainController.dispose();
    _pulseController.dispose();
    _wifiBarsController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _registerServices() async {
    if (!mounted || _hasCompleted || _shouldSkip) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _timeoutTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && _isLoading && !_hasCompleted && !_shouldSkip) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Connection timed out. Please check your internet connection.';
        });
        _stopAllAnimations();
      }
    });

    try {
      await _manager
          .registerServices(retry: _retryCount > 0)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Service registration timed out after 15 seconds',
              );
            },
          );

      if (mounted && !_hasCompleted && !_shouldSkip) {
        _timeoutTimer?.cancel();
        _hasCompleted = true;
        _stopAllAnimations();
        _successController.forward();

        // Wait for success animation to complete
        await Future.delayed(const Duration(milliseconds: 1200));
        widget.onSuccess();
      }
    } on TimeoutException {
      if (mounted && !_hasCompleted && !_shouldSkip) {
        _timeoutTimer?.cancel();
        setState(() {
          _isLoading = false;
          _errorMessage = 'Connection timed out. Please try again.';
        });
        _stopAllAnimations();
      }
    } catch (e) {
      if (mounted && !_hasCompleted && !_shouldSkip) {
        _timeoutTimer?.cancel();
        setState(() {
          _isLoading = false;
          _errorMessage = _getUserFriendlyErrorMessage(e);
        });
        _stopAllAnimations();
      }
    }
  }

  void _stopAllAnimations() {
    _mainController.stop();
    _pulseController.stop();
    _wifiBarsController.stop();
  }

  String _getUserFriendlyErrorMessage(Object error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('no internet') ||
        errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('socket')) {
      return 'Please check your internet connection and try again.';
    } else if (errorString.contains('pusher key not configured') ||
        errorString.contains('runtimeconfig') ||
        errorString.contains('configuration')) {
      return 'Server configuration issue. Please try again.';
    } else if (errorString.contains('auth') || errorString.contains('token')) {
      return 'Authentication error. Please log in again.';
    } else {
      return 'Unable to connect to real-time services. Please try again.';
    }
  }

  void _handleRetry() {
    if (_hasCompleted || _shouldSkip) return;

    setState(() {
      _retryCount++;
      _errorMessage = null;
      _isLoading = true;
    });

    // Restart animations
    _mainController.repeat(reverse: true);
    _pulseController.repeat();
    _wifiBarsController.repeat();

    _registerServices();
  }

  void _handleSkip() {
    if (!mounted || _hasCompleted || _shouldSkip) return;

    _shouldSkip = true;
    _timeoutTimer?.cancel();
    _showSkipConfirmation();
  }

  void _showSkipConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.dark.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Continue Without Real-time Features?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You will not receive live notifications, chat messages, or real-time updates. '
          'You can enable these features later from settings.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _shouldSkip = false;
              });
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _executeSkip();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _executeSkip() {
    if (!mounted || _hasCompleted) return;

    _hasCompleted = true;
    _timeoutTimer?.cancel();
    _stopAllAnimations();
    widget.onSkip();
  }

  bool get _canRetry => _retryCount < 3;

  Widget _buildLoadingAnimation() {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _colorAnimation.value!,
                  _colorAnimation.value!.withOpacity(0.3),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _colorAnimation.value!.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer rotating ring
                Transform.rotate(
                  angle: _rotationAnimation.value * 3.14159 * 2,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _colorAnimation.value!.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ),

                // WiFi icon with animated bars
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi, size: 40, color: Colors.white),
                    const SizedBox(height: 20),

                    // Animated WiFi bars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildWifiBar(1, _wifiBar1Animation.value),
                        const SizedBox(width: 4),
                        _buildWifiBar(2, _wifiBar2Animation.value),
                        const SizedBox(width: 4),
                        _buildWifiBar(3, _wifiBar3Animation.value),
                      ],
                    ),
                  ],
                ),

                // Pulsing dots around the circle
                ...List.generate(8, (index) {
                  final angle = (index / 8) * 3.14159 * 2;
                  final distance = 65.0;
                  final x = distance * -sin(angle);
                  final y = distance * -cos(angle);
                  final dotProgress =
                      (_pulseController.value + (index * 0.125)) % 1.0;

                  return Positioned(
                    left: 80 + x - 4,
                    top: 80 + y - 4,
                    child: Opacity(
                      opacity: 0.7 - (dotProgress * 0.7),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _colorAnimation.value,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWifiBar(int index, double height) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      width: 12,
      height: 8 + (height * 20), // 8 to 28 height
      decoration: BoxDecoration(
        color: _colorAnimation.value,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildErrorAnimation() {
    return GestureDetector(
      onTap: _handleRetry,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseValue = _pulseController.value;

          return Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.orange.withOpacity(0.8 - (pulseValue * 0.3)),
                  Colors.orange.withOpacity(0.3 - (pulseValue * 0.2)),
                ],
              ),
              border: Border.all(
                color: Colors.orange.withOpacity(0.5 - (pulseValue * 0.3)),
                width: 2 + (pulseValue * 2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3 - (pulseValue * 0.2)),
                  blurRadius: 20 + (pulseValue * 10),
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Broken WiFi icon
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 50, color: Colors.white),
                    const SizedBox(height: 10),

                    // Cross icon
                    Transform.rotate(
                      angle: 0.785, // 45 degrees
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),

                // Rotating warning triangles
                ...List.generate(3, (index) {
                  final angle = (index / 3) * 3.14159 * 2;
                  final rotation = _pulseController.value * 3.14159 * 2;

                  return Positioned(
                    left: 70 + 50 * cos(angle + rotation) - 12,
                    top: 70 + 50 * sin(angle + rotation) - 12,
                    child: Transform.rotate(
                      angle: angle + rotation,
                      child: Icon(
                        Icons.warning_amber,
                        size: 24,
                        color: Colors.orange.withOpacity(0.7),
                      ),
                    ),
                  );
                }),

                // "Tap to retry" hint
                Positioned(
                  bottom: 10,
                  child: AnimatedOpacity(
                    opacity: pulseValue > 0.5 ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Tap to retry',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return AnimatedBuilder(
      animation: _successController,
      builder: (context, child) {
        final progress = _successController.value;

        return Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.green.withOpacity(0.8 - (progress * 0.4)),
                Colors.green.withOpacity(0.3 - (progress * 0.2)),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.4 - (progress * 0.2)),
                blurRadius: 30 + (progress * 10),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanding rings
              ...List.generate(3, (index) {
                final ringProgress = progress.clamp(0, 1.0);
                final ringScale = 1.0 + (ringProgress * 0.5) + (index * 0.2);
                final ringOpacity = 1.0 - (ringProgress * 0.7) - (index * 0.2);

                return Transform.scale(
                  scale: ringScale,
                  child: Opacity(
                    opacity: ringOpacity.clamp(0.0, 1.0),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Checkmark
              CustomPaint(
                painter: _AnimatedCheckmarkPainter(
                  progress: progress,
                  color: Colors.white,
                ),
                size: const Size(80, 80),
              ),

              // Rotating sparkles
              ...List.generate(8, (index) {
                final angle = (index / 8) * 3.14159 * 2;
                final sparkleProgress = (progress * 2 - (index * 0.125)).clamp(
                  0.0,
                  1.0,
                );
                final distance = 50.0 + (sparkleProgress * 20);
                final x = distance * cos(angle);
                final y = distance * sin(angle);

                return Positioned(
                  left: 75 + x - 4,
                  top: 75 + y - 4,
                  child: Opacity(
                    opacity: sparkleProgress > 0 ? 1.0 : 0.0,
                    child: Transform.rotate(
                      angle: angle,
                      child: Icon(Icons.star, size: 8, color: Colors.white),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInteractiveProgress() {
    return Column(
      children: [
        SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _pulseController.value,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _colorAnimation.value!,
                  ),
                  minHeight: 6,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Animated dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final dotProgress = (_pulseController.value * 3 - index).clamp(
              0.0,
              1.0,
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 8 + (dotProgress * 4),
                height: 8 + (dotProgress * 4),
                decoration: BoxDecoration(
                  color: _colorAnimation.value!.withOpacity(
                    0.3 + (dotProgress * 0.7),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Main animated container
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeInOutBack,
                    switchOutCurve: Curves.easeInOutBack,
                    child: _isLoading
                        ? _buildLoadingAnimation()
                        : _errorMessage != null
                        ? _buildErrorAnimation()
                        : _buildSuccessAnimation(),
                  ),

                  const SizedBox(height: 40),

                  // Title
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isLoading
                          ? "Checking your connection..."
                          : _errorMessage != null
                          ? 'Connection Issue'
                          : 'All Set!',
                      key: ValueKey(
                        _isLoading
                            ? 'loading'
                            : _errorMessage != null
                            ? 'error'
                            : 'success',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Status message
                  AnimatedOpacity(
                    opacity: _errorMessage != null || !_isLoading ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: _errorMessage != null
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : !_isLoading
                        ? Text(
                            'Real-time features are now active',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                            textAlign: TextAlign.center,
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 32),

                  // Progress indicator or buttons
                  if (_isLoading) ...[
                    _buildInteractiveProgress(),
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: 0.5 + (_pulseController.value * 0.5),
                          child: Text(
                            'Securing your connection...',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white54,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        );
                      },
                    ),
                  ] else if (_errorMessage != null) ...[
                    // Retry button
                    if (_canRetry)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.elasticOut,
                        transform: Matrix4.identity()
                          ..scale(
                            _retryCount == 0
                                ? 1.0
                                : 0.95 + (_retryCount * 0.02),
                          ),
                        child: FilledButton(
                          onPressed: _handleRetry,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: AppColors.primary.withOpacity(0.3),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle: _pulseController.value * 3.14159 * 2,
                                    child: const Icon(Icons.refresh, size: 20),
                                  );
                                },
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Try Again ${_retryCount > 0 ? '($_retryCount)' : ''}',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Skip option
                    // AnimatedOpacity(
                    //   opacity: 0.7,
                    //   duration: const Duration(milliseconds: 500),
                    //   child: TextButton(
                    //     onPressed: _handleSkip,
                    //     style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    //     child: Row(
                    //       mainAxisAlignment: MainAxisAlignment.center,
                    //       children: [
                    //         Icon(
                    //           Icons.arrow_forward,
                    //           size: 16,
                    //           color: Colors.white70,
                    //         ),
                    //         const SizedBox(width: 8),
                    //         Text(
                    //           'Continue without real-time features',
                    //           style: Theme.of(context).textTheme.bodyMedium
                    //               ?.copyWith(color: Colors.white70),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),

                    // Retry count indicator
                    if (_retryCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          '${_retryCount} attempt${_retryCount > 1 ? 's' : ''} made',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white54,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                  ] else ...[
                    // Success state - show celebration
                    AnimatedBuilder(
                      animation: _successController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _successController.value > 0.5
                              ? 1.0
                              : _successController.value * 2,
                          child: Column(
                            children: [
                              const Icon(
                                Icons.celebration,
                                size: 40,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Connected successfully!',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _AnimatedCheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Draw checkmark based on progress
    if (progress < 0.5) {
      // First part of checkmark (from bottom-left to center)
      final firstPartProgress = progress * 2;
      path.moveTo(size.width * 0.2, size.height * 0.6);
      path.lineTo(
        size.width * 0.2 + (size.width * 0.25 * firstPartProgress),
        size.height * 0.6 + (size.height * 0.15 * firstPartProgress),
      );
    } else {
      // Complete first part
      path.moveTo(size.width * 0.2, size.height * 0.6);
      path.lineTo(size.width * 0.45, size.height * 0.75);

      // Second part of checkmark (from center to top-right)
      final secondPartProgress = (progress - 0.5) * 2;
      path.lineTo(
        size.width * 0.45 + (size.width * 0.35 * secondPartProgress),
        size.height * 0.75 - (size.height * 0.35 * secondPartProgress),
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedCheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
