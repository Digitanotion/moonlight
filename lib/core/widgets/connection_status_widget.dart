// lib/core/widgets/connection_status_widget.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moonlight/core/services/connection_monitor.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class ConnectionStatusWidget extends StatefulWidget {
  final bool showOnlyWhenDisconnected;
  final Duration? hideAfter;

  const ConnectionStatusWidget({
    super.key,
    this.showOnlyWhenDisconnected = false,
    this.hideAfter,
  });

  @override
  _ConnectionStatusWidgetState createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  late StreamSubscription<ConnectionStatus> _subscription;
  ConnectionStatus _currentStatus = ConnectionStatus.connected;
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  void _startMonitoring() {
    final monitor = ConnectionMonitor();

    // Get current status
    _currentStatus = monitor.currentStatus;

    // Listen for changes
    _subscription = monitor.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
          _visible = true;
        });

        // Auto-hide after duration if specified
        if (widget.hideAfter != null && status == ConnectionStatus.connected) {
          _hideTimer?.cancel();
          _hideTimer = Timer(widget.hideAfter!, () {
            if (mounted) {
              setState(() {
                _visible = false;
              });
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If we only show when disconnected and we're connected, return empty
    if (widget.showOnlyWhenDisconnected &&
        _currentStatus == ConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    // If not visible, return empty
    if (!_visible) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_currentStatus),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _getStatusColor(),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getStatusIcon(), size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              _getStatusText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.disconnected:
        return Colors.red;
      case ConnectionStatus.slow:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon() {
    switch (_currentStatus) {
      case ConnectionStatus.connected:
        return Icons.wifi;
      case ConnectionStatus.disconnected:
        return Icons.wifi_off;
      case ConnectionStatus.slow:
        return Icons.signal_wifi_statusbar_connected_no_internet_4;
    }
  }

  String _getStatusText() {
    switch (_currentStatus) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.disconnected:
        return 'No internet connection';
      case ConnectionStatus.slow:
        return 'Slow connection';
    }
  }
}
