// lib/features/live_viewer/presentation/widgets/overlays/error_overlay_modern.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:moonlight/features/live_viewer/domain/entities/error_types.dart';

/// Ultra-modern error overlay for live viewer
class ModernErrorOverlay extends StatefulWidget {
  final LiveViewerErrorType errorType;
  final String? customMessage;
  final VoidCallback? onRetry;
  final VoidCallback onExit;
  final bool allowRetry;

  const ModernErrorOverlay({
    super.key,
    required this.errorType,
    this.customMessage,
    this.onRetry,
    required this.onExit,
    this.allowRetry = false,
  });

  @override
  State<ModernErrorOverlay> createState() => _ModernErrorOverlayState();
}

class _ModernErrorOverlayState extends State<ModernErrorOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _blurAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Color?> _backgroundColorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const ElasticOutCurve(0.8)),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _blurAnimation = Tween<double>(
      begin: 0.0,
      end: 15.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
        );

    _backgroundColorAnimation = ColorTween(
      begin: Colors.black.withOpacity(0),
      end: Colors.black.withOpacity(0.85),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getTitle() {
    return switch (widget.errorType) {
      LiveViewerErrorType.accessRevoked => 'Access Revoked',
      LiveViewerErrorType.streamNotActive => 'Stream Not Active',
      LiveViewerErrorType.streamEnded => 'Stream Ended',
      LiveViewerErrorType.removedByHost => 'Removed by Host',
      LiveViewerErrorType.networkError => 'Connection Lost',
      LiveViewerErrorType.permissionDenied => 'Permission Denied',
      LiveViewerErrorType.ageRestricted => 'Age Restricted',
      LiveViewerErrorType.privateStream => 'Private Stream',
      LiveViewerErrorType.geoBlocked => 'Not Available',
      LiveViewerErrorType.technicalError => 'Technical Issue',
    };
  }

  String _getMessage() {
    return widget.customMessage ??
        switch (widget.errorType) {
          LiveViewerErrorType.accessRevoked =>
            'You no longer have access to this livestream.',
          LiveViewerErrorType.streamNotActive =>
            'This livestream is not currently active.',
          LiveViewerErrorType.streamEnded => 'The livestream has ended.',
          LiveViewerErrorType.removedByHost =>
            'You have been removed from this livestream by the host.',
          LiveViewerErrorType.networkError =>
            'Unable to connect. Please check your internet connection.',
          LiveViewerErrorType.permissionDenied =>
            'You do not have permission to view this content.',
          LiveViewerErrorType.ageRestricted =>
            'This content is age restricted.',
          LiveViewerErrorType.privateStream =>
            'This is a private livestream. You need an invitation.',
          LiveViewerErrorType.geoBlocked =>
            'This content is not available in your region.',
          LiveViewerErrorType.technicalError =>
            'A technical issue occurred. Please try again later.',
        };
  }

  String _getLottieAsset() {
    return switch (widget.errorType) {
      LiveViewerErrorType.accessRevoked => 'assets/lottie/lock.json',
      LiveViewerErrorType.streamNotActive => 'assets/lottie/offline.json',
      LiveViewerErrorType.streamEnded => 'assets/lottie/ended.json',
      LiveViewerErrorType.removedByHost => 'assets/lottie/removed.json',
      LiveViewerErrorType.networkError => 'assets/lottie/wifi_error.json',
      LiveViewerErrorType.permissionDenied => 'assets/lottie/shield.json',
      LiveViewerErrorType.ageRestricted => 'assets/lottie/age_restricted.json',
      LiveViewerErrorType.privateStream => 'assets/lottie/private.json',
      LiveViewerErrorType.geoBlocked => 'assets/lottie/globe.json',
      LiveViewerErrorType.technicalError => 'assets/lottie/error.json',
    };
  }

  Color _getPrimaryColor() {
    return switch (widget.errorType) {
      LiveViewerErrorType.accessRevoked => const Color(0xFFFF7043),
      LiveViewerErrorType.streamNotActive => const Color(0xFF5C6BC0),
      LiveViewerErrorType.streamEnded => const Color(0xFFAB47BC),
      LiveViewerErrorType.removedByHost => const Color(0xFFEF5350),
      LiveViewerErrorType.networkError => const Color(0xFF42A5F5),
      LiveViewerErrorType.permissionDenied => const Color(0xFFFFA726),
      LiveViewerErrorType.ageRestricted => const Color(0xFFEC407A),
      LiveViewerErrorType.privateStream => const Color(0xFF26A69A),
      LiveViewerErrorType.geoBlocked => const Color(0xFF7E57C2),
      LiveViewerErrorType.technicalError => const Color(0xFF78909C),
    };
  }

  @override
  Widget build(BuildContext context) {
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
            width: double.infinity,
            height: double.infinity,
            color: _backgroundColorAnimation.value,
            child: Stack(
              children: [
                // Animated background particles
                _buildAnimatedBackground(),

                // Main content
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildContentCard(isDark),
                        ),
                      ),
                    ),
                  ),
                ),

                // Exit button (top right)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  right: 20,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildExitButton(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentCard(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 450),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: -10,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: _getPrimaryColor().withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Lottie icon
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  _getPrimaryColor().withOpacity(0.2),
                  _getPrimaryColor().withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Lottie.asset(
                _getLottieAsset(),
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Title with gradient
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [_getPrimaryColor(), _getPrimaryColor().withOpacity(0.8)],
            ).createShader(bounds),
            child: Text(
              _getTitle(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Message
          Text(
            _getMessage(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white.withOpacity(0.7) : Colors.grey[700],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.allowRetry && widget.onRetry != null)
                _buildRetryButton(),
              const SizedBox(width: 16),
              _buildExitButton(isPrimary: true),
            ],
          ),

          const SizedBox(height: 16),

          // Optional help text
          if (_shouldShowHelpText())
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _getHelpText(),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return OutlinedButton(
      onPressed: () {
        _controller.reverse().then((_) {
          if (widget.onRetry != null) {
            widget.onRetry!();
          }
        });
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: _getPrimaryColor(), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh_rounded, color: _getPrimaryColor(), size: 20),
          const SizedBox(width: 10),
          Text(
            'Try Again',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _getPrimaryColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExitButton({bool isPrimary = false}) {
    return ElevatedButton(
      onPressed: () {
        _controller.reverse().then((_) => widget.onExit());
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? _getPrimaryColor() : Colors.transparent,
        foregroundColor: isPrimary
            ? Colors.white
            : Colors.white.withOpacity(0.8),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: isPrimary ? 8 : 0,
        shadowColor: _getPrimaryColor().withOpacity(0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPrimary ? Icons.arrow_back_rounded : Icons.close_rounded,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            isPrimary ? 'Return Home' : '',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  bool _shouldShowHelpText() {
    return widget.errorType == LiveViewerErrorType.accessRevoked ||
        widget.errorType == LiveViewerErrorType.permissionDenied ||
        widget.errorType == LiveViewerErrorType.ageRestricted;
  }

  String _getHelpText() {
    return switch (widget.errorType) {
      LiveViewerErrorType.accessRevoked =>
        'Contact the stream host if you believe this is a mistake.',
      LiveViewerErrorType.permissionDenied =>
        'You may need to verify your account or request access.',
      LiveViewerErrorType.ageRestricted =>
        'You must be 18+ to view this content.',
      _ => '',
    };
  }

  Widget _buildAnimatedBackground() {
    return IgnorePointer(
      child: CustomPaint(
        painter: _AnimatedBackgroundPainter(
          animation: _controller,
          primaryColor: _getPrimaryColor(),
        ),
      ),
    );
  }
}

class _AnimatedBackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final Color primaryColor;

  _AnimatedBackgroundPainter({
    required this.animation,
    required this.primaryColor,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final time = animation.value * 2 * pi;

    // Draw gradient background
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.5,
      colors: [primaryColor.withOpacity(0.05), Colors.transparent],
    );

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width,
      height: size.height,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.overlay;

    canvas.drawRect(rect, paint);

    // Draw floating particles
    final particlePaint = Paint()
      ..color = primaryColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final particleCount = 15;
    for (int i = 0; i < particleCount; i++) {
      final x =
          size.width * 0.5 +
          size.width *
              0.3 *
              sin(time * 0.3 + i * 2 * pi / particleCount) *
              cos(time * 0.5);
      final y =
          size.height * 0.5 +
          size.height *
              0.3 *
              cos(time * 0.7 + i * 2 * pi / particleCount) *
              sin(time * 0.4);

      final radius = 3 + sin(time + i) * 2;

      canvas.drawCircle(Offset(x, y), radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedBackgroundPainter oldDelegate) {
    return animation != oldDelegate.animation ||
        primaryColor != oldDelegate.primaryColor;
  }
}
