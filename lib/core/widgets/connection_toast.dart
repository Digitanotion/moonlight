// lib/core/widgets/connection_toast.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moonlight/core/services/connection_monitor.dart';

class SimpleConnectionToast extends StatefulWidget {
  final Widget child;
  const SimpleConnectionToast({super.key, required this.child});

  @override
  _SimpleConnectionToastState createState() => _SimpleConnectionToastState();

  /// Set to true when PiP is active — toast is fully removed from layout.
  static final ValueNotifier<bool> pipActive = ValueNotifier(false);
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
      if (_currentStatus == status) return;
      _currentStatus = status;
      _hideTimer?.cancel();
      setState(() => _showToast = true);
      final duration = switch (status) {
        ConnectionStatus.disconnected => const Duration(seconds: 4),
        ConnectionStatus.slow        => const Duration(seconds: 3),
        _                            => const Duration(seconds: 2),
      };
      _hideTimer = Timer(duration, () {
        if (mounted) setState(() => _showToast = false);
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  Color _bgColor() => switch (_currentStatus) {
    ConnectionStatus.connected    => Colors.green,
    ConnectionStatus.disconnected => Colors.red,
    ConnectionStatus.slow         => Colors.orange,
  };

  IconData _icon() => switch (_currentStatus) {
    ConnectionStatus.connected    => Icons.wifi,
    ConnectionStatus.disconnected => Icons.wifi_off,
    ConnectionStatus.slow         => Icons.signal_cellular_alt,
  };

  String _title() => switch (_currentStatus) {
    ConnectionStatus.connected    => 'Connected',
    ConnectionStatus.disconnected => 'No Connection',
    ConnectionStatus.slow         => 'Slow Network',
  };

  String _message() => switch (_currentStatus) {
    ConnectionStatus.connected    => "You're back online",
    ConnectionStatus.disconnected => 'Check your internet connection',
    ConnectionStatus.slow         => 'Connection is slow',
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder<bool>(
          valueListenable: SimpleConnectionToast.pipActive,
          builder: (_, inPip, __) {
            // Offstage completely removes from layout when PiP is active
            // or toast is hidden — no overlap with video possible.
            if (inPip || !_showToast) return const SizedBox.shrink();
            return Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _bgColor(),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(children: [
                    Icon(_icon(), color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_title(), style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                        Text(_message(), style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
                      ],
                    )),
                  ]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}