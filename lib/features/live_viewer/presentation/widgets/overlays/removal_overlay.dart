import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/features/live_viewer/domain/repositories/viewer_repository.dart';

/// Ultra-modern overlay for when a user is removed from a livestream
/// with a call-to-action to return to the app
class RemovalOverlay extends StatefulWidget {
  final VoidCallback onReturn;
  final ViewerRepository repository;
  const RemovalOverlay({
    super.key,
    required this.onReturn,
    required this.repository,
  });

  @override
  State<RemovalOverlay> createState() => _RemovalOverlayState();
}

class _RemovalOverlayState extends State<RemovalOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _blurAnimation;
  late Animation<Offset> _slideAnimation;
  final reason = "removed_by_host";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
        );

    // Start animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
      // Vibrate for haptic feedback
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getRemovalTitle() {
    switch (reason) {
      case 'removed_by_host':
        return 'Removed by Host';
      case 'violated_guidelines':
        return 'Guidelines Violation';
      case 'inappropriate_content':
        return 'Content Policy';
      case 'technical_issue':
        return 'Technical Issue';
      default:
        return 'Stream Ended';
    }
  }

  String _getRemovalMessage() {
    switch (reason) {
      case 'removed_by_host':
        return 'The host has removed you from this livestream.';
      case 'violated_guidelines':
        return 'Your participation violated community guidelines.';
      case 'inappropriate_content':
        return 'Content shared was against our community standards.';
      case 'technical_issue':
        return 'A technical issue required your removal.';
      default:
        return 'This livestream is no longer available.';
    }
  }

  Widget _buildRemovalIcon() {
    switch (reason) {
      case 'removed_by_host':
        return const Icon(
          Icons.person_off_rounded,
          size: 72,
          color: Colors.orangeAccent,
        );
      case 'violated_guidelines':
      case 'inappropriate_content':
        return const Icon(
          Icons.gpp_bad_rounded,
          size: 72,
          color: Colors.redAccent,
        );
      default:
        return const Icon(
          Icons.error_outline_rounded,
          size: 72,
          color: Colors.blueAccent,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _blurAnimation.value,
            sigmaY: _blurAnimation.value,
          ),
          child: Container(
            width: size.width,
            height: size.height,
            color: Colors.black.withOpacity(0.7 * _fadeAnimation.value),
            child: Stack(
              children: [
                // Background particles effect
                _buildParticles(),

                // Main content
                Center(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildContent(isDark),
                      ),
                    ),
                  ),
                ),

                // Close button (top right)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: IconButton(
                      onPressed: () {
                        _controller.reverse().then((_) => widget.onReturn());
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 28,
                      ),
                      splashRadius: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: -10,
            offset: const Offset(0, 20),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getIconColor().withOpacity(0.15),
                  _getIconColor().withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(child: _buildRemovalIcon()),
          ),

          const SizedBox(height: 32),

          // Title
          Text(
            _getRemovalTitle(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Message
          Text(
            _getRemovalMessage(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : const Color(0xFF666666),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // CTA Button
          _buildReturnButton(isDark),
          const SizedBox(height: 16),

          // Optional tip
          if (reason != 'technical_issue')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Review our community guidelines to avoid this in the future.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withOpacity(0.5)
                      : const Color(0xFF999999),
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReturnButton(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_getButtonColor(), _getButtonColor().withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getButtonColor().withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _controller.reverse().then((_) => widget.onReturn());
          },
          onHover: (hovering) {
            setState(() {});
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Return Now',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getIconColor() {
    switch (reason) {
      case 'removed_by_host':
        return const Color(0xFFFFA726);
      case 'violated_guidelines':
      case 'inappropriate_content':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF42A5F5);
    }
  }

  Color _getButtonColor() {
    switch (reason) {
      case 'removed_by_host':
        return const Color(0xFFFF7043);
      case 'violated_guidelines':
      case 'inappropriate_content':
        return const Color(0xFFEC407A);
      default:
        return const Color(0xFF5C6BC0);
    }
  }

  Widget _buildParticles() {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ParticlesPainter(
          animation: _controller,
          color: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }
}

/// Custom painter for background particles effect
class _ParticlesPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _ParticlesPainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    final particleCount = 20;
    final time = animation.value * 2 * pi;

    for (int i = 0; i < particleCount; i++) {
      final x =
          size.width * 0.5 +
          size.width *
              0.4 *
              cos(time * 0.5 + i * 2 * pi / particleCount) *
              sin(time * 0.3);
      final y =
          size.height * 0.5 +
          size.height *
              0.4 *
              sin(time * 0.7 + i * 2 * pi / particleCount) *
              cos(time * 0.4);

      final radius = 2 + sin(time + i) * 1;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) {
    return animation != oldDelegate.animation || color != oldDelegate.color;
  }
}

/// Usage in your LiveViewerOrchestrator or ViewerBloc:
/// 
/// When you receive a participant.removed event with the current user's UUID:
/// 
/// ```dart
/// // In your ViewerBloc or wherever you handle removal
/// on<ViewerRemovedEvent>((event, emit) {
///   // Show the overlay
///   showDialog(
///     context: context,
///     barrierDismissible: false,
///     barrierColor: Colors.transparent,
///     builder: (context) => RemovalOverlay(
///       reason: event.reason,
///       onReturn: () {
///         // Close the overlay and navigate back
///         Navigator.of(context).popUntil((route) => route.isFirst);
///         // Or close the entire LiveViewer screen
///         Navigator.of(context).pop();
///       },
///     ),
///   );
/// });
/// ```