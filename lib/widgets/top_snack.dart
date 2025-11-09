import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

/// TopSnack: overlay-based, top-positioned snackbar/toast.
/// Always uses the root overlay so it appears above sheets and dialogs.
class TopSnack {
  static OverlayEntry? _entry;
  static Timer? _timer;

  // Primary show method
  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    Color bgStart = const Color(0xFF141418),
    Color bgEnd = const Color(0xFF0B0B0D),
    Color accent = const Color(0xFFFF7A00),
    bool force = false,
  }) {
    // If already shown and not forced, extend timer
    if (_entry != null && !force) {
      _resetTimer(duration);
      return;
    }

    _removeExisting();

    final media = MediaQuery.of(context);
    final topPadding = media.padding.top;

    final overlayState = Overlay.of(context, rootOverlay: true);
    if (overlayState == null) return;

    _entry = OverlayEntry(
      builder: (_) {
        return _TopSnackOverlay(
          message: message,
          icon: icon,
          actionLabel: actionLabel,
          onAction: onAction,
          topPadding: topPadding,
          bgStart: bgStart,
          bgEnd: bgEnd,
          accent: accent,
        );
      },
    );

    overlayState.insert(_entry!);
    _timer = Timer(duration, _removeExisting);
  }

  static void _resetTimer(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, _removeExisting);
  }

  static void _removeExisting() {
    try {
      _timer?.cancel();
      _timer = null;
      _entry?.remove();
      _entry = null;
    } catch (_) {}
  }

  // Convenience variants
  static void success(
    BuildContext ctx,
    String msg, {
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
  }) => show(
    ctx,
    msg,
    icon: Icons.check_circle,
    duration: duration,
    bgStart: const Color(0xFF113B00),
    bgEnd: const Color(0xFF072600),
    accent: const Color(0xFF4CAF50),
    onAction: onAction,
  );

  static void error(
    BuildContext ctx,
    String msg, {
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onAction,
  }) => show(
    ctx,
    msg,
    icon: Icons.error_outline,
    duration: duration,
    bgStart: const Color(0xFF3E0F0F),
    bgEnd: const Color(0xFF2A0A0A),
    accent: const Color(0xFFFF6B6B),
    onAction: onAction,
  );

  static void info(
    BuildContext ctx,
    String msg, {
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
  }) => show(
    ctx,
    msg,
    icon: Icons.info_outline,
    duration: duration,
    bgStart: const Color(0xFF16304A),
    bgEnd: const Color(0xFF0B1B2A),
    accent: const Color(0xFF2196F3),
    onAction: onAction,
  );
}

class _TopSnackOverlay extends StatefulWidget {
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double topPadding;
  final Color bgStart;
  final Color bgEnd;
  final Color accent;

  const _TopSnackOverlay({
    Key? key,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    required this.topPadding,
    required this.bgStart,
    required this.bgEnd,
    required this.accent,
  }) : super(key: key);

  @override
  State<_TopSnackOverlay> createState() => _TopSnackOverlayState();
}

class _TopSnackOverlayState extends State<_TopSnackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topPadding + 12,
      left: 12,
      right: 12,
      child: FadeTransition(
        opacity: _anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.1),
            end: Offset.zero,
          ).animate(_anim),
          child: SafeArea(
            minimum: EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.bgStart, widget.bgEnd],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Row(
                      children: [
                        if (widget.icon != null)
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: widget.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              widget.icon,
                              color: widget.accent,
                              size: 20,
                            ),
                          ),
                        if (widget.icon != null) const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (widget.actionLabel != null)
                          TextButton(
                            onPressed: () {
                              widget.onAction?.call();
                              TopSnack._removeExisting();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: widget.accent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(widget.actionLabel!),
                          ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => TopSnack._removeExisting(),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
