import 'dart:async';
import 'package:flutter/material.dart';

/// Usage:
/// MoonSnack.show(
///   context,
///   message: "Profile updated",
///   type: MoonSnackType.success,
/// );
///
/// Shortcuts:
/// MoonSnack.success(context, "Saved");
/// MoonSnack.error(context, "Something went wrong");
/// MoonSnack.warning(context, "Heads up");

enum MoonSnackType { success, error, warning }

class MoonSnack {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void success(
    BuildContext context,
    String message, {
    Duration? duration,
  }) => show(
    context,
    message: message,
    type: MoonSnackType.success,
    duration: duration,
  );

  static void error(
    BuildContext context,
    String message, {
    Duration? duration,
  }) => show(
    context,
    message: message,
    type: MoonSnackType.error,
    duration: duration,
  );

  static void warning(
    BuildContext context,
    String message, {
    Duration? duration,
  }) => show(
    context,
    message: message,
    type: MoonSnackType.warning,
    duration: duration,
  );

  static void show(
    BuildContext context, {
    required String message,
    required MoonSnackType type,
    Duration? duration,
    String? title,
  }) {
    // Remove any showing snack first
    _removeCurrent();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final theme = Theme.of(context);
    final colors = _paletteFor(type, theme.brightness);

    final entry = OverlayEntry(
      builder: (ctx) {
        // Use MediaQuery to get safe area top padding
        final paddingTop = MediaQuery.of(ctx).padding.top;
        return _TopToastContainer(
          child: GestureDetector(
            onTap: _removeCurrent,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.only(top: paddingTop + 12),
                    child: _MoonSnackCard(
                      title: title,
                      message: message,
                      bg: colors.bg,
                      border: colors.border,
                      iconBg: colors.iconBg,
                      icon: colors.icon,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    _currentEntry = entry;

    // Auto dismiss
    _timer = Timer(
      duration ?? const Duration(seconds: 2, milliseconds: 200),
      () {
        _removeCurrent();
      },
    );
  }

  static void _removeCurrent() {
    _timer?.cancel();
    _timer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  // Ensure we remove when route changes to prevent leaks
  static void attachRouteAware(NavigatorState navigator) {
    navigator.widget.observers.add(_MoonSnackRouteObserver());
  }

  static _MoonPalette _paletteFor(MoonSnackType type, Brightness brightness) {
    // You can wire these into your AppColors if you like.
    switch (type) {
      case MoonSnackType.success:
        return _MoonPalette(
          bg: brightness == Brightness.dark
              ? const Color(0xFF0B2B19)
              : const Color(0xFFE9F8EF),
          border: brightness == Brightness.dark
              ? const Color(0xFF0FA958)
              : const Color(0xFF10B981),
          iconBg: brightness == Brightness.dark
              ? const Color(0xFF0F3D25)
              : const Color(0xFFD9F5E5),
          icon: brightness == Brightness.dark
              ? const Color(0xFF22C55E)
              : const Color(0xFF059669),
        );
      case MoonSnackType.error:
        return _MoonPalette(
          bg: brightness == Brightness.dark
              ? const Color(0xFF3A0D0D)
              : const Color(0xFFFDECEC),
          border: brightness == Brightness.dark
              ? const Color(0xFFF87171)
              : const Color(0xFFEF4444),
          iconBg: brightness == Brightness.dark
              ? const Color(0xFF4A1414)
              : const Color(0xFFFCE3E3),
          icon: brightness == Brightness.dark
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFDC2626),
        );
      case MoonSnackType.warning:
        return _MoonPalette(
          bg: brightness == Brightness.dark
              ? const Color(0xFF2F2400)
              : const Color(0xFFFFF7E6),
          border: brightness == Brightness.dark
              ? const Color(0xFFF59E0B)
              : const Color(0xFFF59E0B),
          iconBg: brightness == Brightness.dark
              ? const Color(0xFF3C2F00)
              : const Color(0xFFFFF1CF),
          icon: brightness == Brightness.dark
              ? const Color(0xFFFBBF24)
              : const Color(0xFFD97706),
        );
    }
  }
}

class _MoonPalette {
  final Color bg;
  final Color border;
  final Color iconBg;
  final Color icon;
  const _MoonPalette({
    required this.bg,
    required this.border,
    required this.iconBg,
    required this.icon,
  });
}

class _TopToastContainer extends StatefulWidget {
  final Widget child;
  const _TopToastContainer({super.key, required this.child});

  @override
  State<_TopToastContainer> createState() => _TopToastContainerState();
}

class _TopToastContainerState extends State<_TopToastContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -0.2),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

class _MoonSnackCard extends StatelessWidget {
  final String? title;
  final String message;
  final Color bg;
  final Color border;
  final Color iconBg;
  final Color icon;

  const _MoonSnackCard({
    required this.message,
    required this.bg,
    required this.border,
    required this.iconBg,
    required this.icon,
    this.title,
  });

  IconData _iconData() {
    if (icon.value == const Color(0xFF059669).value ||
        icon.value == const Color(0xFF22C55E).value) {
      return Icons.check_circle_rounded;
    }
    if (icon.value == const Color(0xFFDC2626).value ||
        icon.value == const Color(0xFFFCA5A5).value) {
      return Icons.error_rounded;
    }
    return Icons.warning_amber_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF111827);

    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withOpacity(0.7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(_iconData(), color: icon, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.trim().isNotEmpty)
                  Text(
                    title!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              // Close by tapping the ×
              // The static remover will handle it:
              // ignore: invalid_use_of_protected_member
              // call via MoonSnack.show() tap area; handled above.
            },
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: textColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoonSnackRouteObserver extends NavigatorObserver {
  @override
  void didPop(Route route, Route? previousRoute) {
    MoonSnack._removeCurrent();
    super.didPop(route, previousRoute);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    MoonSnack._removeCurrent();
    super.didPush(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    MoonSnack._removeCurrent();
    super.didRemove(route, previousRoute);
  }
}
