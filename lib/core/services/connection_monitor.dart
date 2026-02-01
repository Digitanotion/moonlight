// lib/core/services/connection_monitor.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

enum ConnectionStatus { connected, disconnected, slow }

class ConnectionMonitor {
  static final ConnectionMonitor _instance = ConnectionMonitor._internal();
  factory ConnectionMonitor() => _instance;
  ConnectionMonitor._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  Timer? _monitorTimer;
  Timer? _slowCheckTimer;
  ConnectionStatus _currentStatus = ConnectionStatus.connected;
  bool _isMonitoring = false;

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus get currentStatus => _currentStatus;

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    debugPrint('🔍 Starting enhanced connection monitoring');

    // Initial check
    await _performEnhancedCheck();

    // Periodic checks every 15 seconds (less frequent to save battery)
    _monitorTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _performEnhancedCheck();
    });

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((result) async {
      debugPrint('📡 Connectivity changed: $result');
      await _performEnhancedCheck();
    });
  }

  Future<void> _performEnhancedCheck() async {
    try {
      // First check basic connectivity
      final connectivityResult = await _connectivity.checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        _updateStatus(ConnectionStatus.disconnected);
        return;
      }

      // We have some connectivity, now check real internet access
      final hasInternet = await _checkRealInternetAccess();

      if (!hasInternet) {
        _updateStatus(ConnectionStatus.disconnected);
        return;
      }

      // Check if connection is slow
      final isSlow = await _checkIfSlowConnection();

      if (isSlow) {
        _updateStatus(ConnectionStatus.slow);
      } else {
        _updateStatus(ConnectionStatus.connected);
      }
    } catch (e) {
      debugPrint('❌ Error in enhanced connection check: $e');
      _updateStatus(ConnectionStatus.disconnected);
    }
  }

  Future<bool> _checkRealInternetAccess() async {
    try {
      final dio = Dio();

      // Try multiple endpoints for reliability
      final endpoints = [
        'https://www.gstatic.com/generate_204',
        'https://connectivitycheck.gstatic.com/generate_204',
        'https://clients3.google.com/generate_204',
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await dio.get(
            endpoint,
            options: Options(
              receiveTimeout: const Duration(seconds: 4),
              sendTimeout: const Duration(seconds: 4),
            ),
          );

          // 204 No Content or 200 OK are both valid responses
          if (response.statusCode == 204 || response.statusCode == 200) {
            return true;
          }
        } catch (e) {
          // Try next endpoint
          continue;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkIfSlowConnection() async {
    try {
      final dio = Dio();
      final stopwatch = Stopwatch()..start();

      final response = await dio.get(
        'https://www.gstatic.com/generate_204',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      stopwatch.stop();

      // Consider slow if response takes more than 2 seconds
      return stopwatch.elapsedMilliseconds > 2000;
    } catch (e) {
      return true; // If we can't measure, assume slow
    }
  }

  void _updateStatus(ConnectionStatus newStatus) {
    if (newStatus != _currentStatus) {
      debugPrint('📡 Connection status changed: $newStatus');
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) return false;

    return await _checkRealInternetAccess();
  }

  Future<void> stopMonitoring() {
    _isMonitoring = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _slowCheckTimer?.cancel();
    _slowCheckTimer = null;
    debugPrint('🛑 Stopped connection monitoring');
    return _statusController.close();
  }
}
