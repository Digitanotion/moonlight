// lib/core/widgets/connection_toast.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moonlight/core/services/connection_monitor.dart';
import 'package:moonlight/core/theme/app_colors.dart';

// Alternative ConnectionToast that doesn't use overlay
class SimpleConnectionToast extends StatefulWidget {
  final Widget child;

  const SimpleConnectionToast({super.key, required this.child});

  @override
  _SimpleConnectionToastState createState() => _SimpleConnectionToastState();
}

class _SimpleConnectionToastState extends State<SimpleConnectionToast> {
  late StreamSubscription<ConnectionStatus> _subscription;
  ConnectionStatus _currentStatus = ConnectionStatus.connected;
  bool _showToast = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _listenToConnection();
  }

  void _listenToConnection() {
    final monitor = ConnectionMonitor();

    _subscription = monitor.statusStream.listen((status) {
      if (!mounted) return;

      if (_currentStatus != status) {
        _currentStatus = status;

        // Show toast
        setState(() {
          _showToast = true;
        });

        // Auto-hide for connected/slow status
        if (status == ConnectionStatus.connected) {
          _hideTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _showToast = false;
              });
            }
          });
        } else if (status == ConnectionStatus.slow) {
          _hideTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _showToast = false;
              });
            }
          });
        }
        // Disconnected stays until manually dismissed
      }
    });
  }

  Widget _buildToast() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: _showToast ? 16 : -100,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(_getIcon(), color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTitle(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _getMessage(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_currentStatus == ConnectionStatus.disconnected)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: () {
                    setState(() {
                      _showToast = false;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (_currentStatus) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.disconnected:
        return Colors.red;
      case ConnectionStatus.slow:
        return Colors.orange;
    }
  }

  IconData _getIcon() {
    switch (_currentStatus) {
      case ConnectionStatus.connected:
        return Icons.wifi;
      case ConnectionStatus.disconnected:
        return Icons.wifi_off;
      case ConnectionStatus.slow:
        return Icons.signal_cellular_alt;
    }
  }

  String _getTitle() {
    switch (_currentStatus) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.disconnected:
        return 'No Connection';
      case ConnectionStatus.slow:
        return 'Slow Network';
    }
  }

  String _getMessage() {
    switch (_currentStatus) {
      case ConnectionStatus.connected:
        return 'You\'re back online';
      case ConnectionStatus.disconnected:
        return 'Check your internet connection';
      case ConnectionStatus.slow:
        return 'Connection is slow';
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Toast
        _buildToast(),
      ],
    );
  }
}
