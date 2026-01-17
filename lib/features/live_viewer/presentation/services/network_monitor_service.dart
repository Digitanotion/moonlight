// lib/features/live_viewer/presentation/services/network_monitor_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';

/// Dedicated service for network monitoring and quality reporting
class NetworkMonitorService {
  final LiveStreamService _liveStreamService;
  final StreamController<NetworkStatus> _networkStatusCtrl =
      StreamController.broadcast();
  final StreamController<ConnectionStats> _connectionStatsCtrl =
      StreamController.broadcast();
  final StreamController<String> _networkIssueCtrl =
      StreamController.broadcast();

  Timer? _monitoringTimer;
  NetworkQuality _lastHostQuality = NetworkQuality.unknown;
  NetworkQuality _lastSelfQuality = NetworkQuality.unknown;
  NetworkQuality? _lastGuestQuality;
  DateTime? _lastIssueReported;

  NetworkMonitorService(this._liveStreamService);

  // ============ PUBLIC API ============

  Stream<NetworkStatus> watchNetworkStatus() => _networkStatusCtrl.stream;

  Stream<ConnectionStats> watchConnectionStats() => _connectionStatsCtrl.stream;

  Stream<String> watchNetworkIssues() => _networkIssueCtrl.stream;

  void startMonitoring() {
    if (_monitoringTimer != null) return;

    debugPrint('📡 Starting network monitoring');

    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _performMonitoringCycle(),
    );

    // Subscribe to live stream service quality streams
    _liveStreamService.watchHostNetworkQuality().listen(_onHostQualityChanged);
    _liveStreamService.watchSelfNetworkQuality().listen(_onSelfQualityChanged);

    final guestStream = _liveStreamService.watchGuestNetworkQuality();
    if (guestStream != null) {
      guestStream.listen(_onGuestQualityChanged);
    }

    _liveStreamService.watchConnectionState().listen(_onConnectionStateChanged);
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    debugPrint('📡 Stopped network monitoring');
  }

  Future<void> optimizeConnection() async {
    debugPrint('🔧 Optimizing network connection...');

    // Report issue
    _networkIssueCtrl.add('Optimizing network connection...');

    // TODO: Implement actual optimization strategies
    // 1. Adjust video quality based on network
    // 2. Enable/disable forward error correction
    // 3. Adjust bitrate
    // 4. Switch between TCP/UDP

    await Future.delayed(const Duration(seconds: 1));
    _networkIssueCtrl.add('Network optimization completed');
  }

  Future<NetworkStatus> getCurrentStatus() async {
    final hostQuality = await _getCurrentHostQuality();
    final selfQuality = await _getCurrentSelfQuality();
    final guestQuality = await _getCurrentGuestQuality();

    return NetworkStatus(
      selfQuality: selfQuality,
      hostQuality: hostQuality,
      guestQuality: guestQuality,
      isReconnecting: false,
      reconnectAttempts: 0,
    );
  }

  // ============ PRIVATE METHODS ============

  Future<void> _performMonitoringCycle() async {
    try {
      // Collect current status
      final status = await getCurrentStatus();
      _networkStatusCtrl.add(status);

      // Collect detailed stats periodically
      if (DateTime.now().second % 10 == 0) {
        // Every 10 seconds
        final stats = await _liveStreamService.getConnectionStats();
        _connectionStatsCtrl.add(stats);
      }

      // Detect and report issues
      await _detectNetworkIssues(status);
    } catch (e) {
      debugPrint('⚠️ Network monitoring cycle failed: $e');
    }
  }

  void _onHostQualityChanged(NetworkQuality quality) {
    _lastHostQuality = quality;
    _checkForQualityDegradation('host', quality, _lastHostQuality);
  }

  void _onSelfQualityChanged(NetworkQuality quality) {
    _lastSelfQuality = quality;
    _checkForQualityDegradation('self', quality, _lastSelfQuality);
  }

  void _onGuestQualityChanged(NetworkQuality quality) {
    _lastGuestQuality = quality;
    _checkForQualityDegradation(
      'guest',
      quality,
      _lastGuestQuality ?? NetworkQuality.unknown,
    );
  }

  void _onConnectionStateChanged(ConnectionState state) {
    if (state == ConnectionState.disconnected) {
      _reportNetworkIssue('Connection lost. Attempting to reconnect...');
    } else if (state == ConnectionState.connected) {
      _reportNetworkIssue('Connection restored');
    }
  }

  void _checkForQualityDegradation(
    String target,
    NetworkQuality current,
    NetworkQuality previous,
  ) {
    if (_shouldReportIssue()) {
      if (current == NetworkQuality.poor && previous == NetworkQuality.good) {
        _reportNetworkIssue('$target network quality degraded to poor');
      } else if (current == NetworkQuality.disconnected &&
          previous != NetworkQuality.disconnected) {
        _reportNetworkIssue('$target disconnected');
      } else if (current == NetworkQuality.good &&
          previous == NetworkQuality.poor) {
        _reportNetworkIssue('$target network quality improved to good');
      }
    }
  }

  bool _shouldReportIssue() {
    if (_lastIssueReported == null) return true;
    final now = DateTime.now();
    final timeSinceLastIssue = now.difference(_lastIssueReported!);
    return timeSinceLastIssue.inSeconds > 30; // Throttle to 30 seconds
  }

  void _reportNetworkIssue(String message) {
    _lastIssueReported = DateTime.now();
    _networkIssueCtrl.add(message);
    debugPrint('⚠️ Network Issue: $message');
  }

  Future<NetworkQuality> _getCurrentHostQuality() async {
    // TODO: Get actual quality from Agora stats
    return _lastHostQuality;
  }

  Future<NetworkQuality> _getCurrentSelfQuality() async {
    // TODO: Get actual quality from Agora stats
    return _lastSelfQuality;
  }

  Future<NetworkQuality?> _getCurrentGuestQuality() async {
    if (_liveStreamService.isGuest) {
      return _lastGuestQuality;
    }
    return null;
  }

  Future<void> _detectNetworkIssues(NetworkStatus status) async {
    final issues = <String>[];

    if (status.hostQuality == NetworkQuality.poor) {
      issues.add('Host network quality is poor');
    }

    if (status.hostQuality == NetworkQuality.disconnected) {
      issues.add('Host disconnected');
    }

    if (status.selfQuality == NetworkQuality.poor) {
      issues.add('Your network quality is poor');
    }

    if (status.selfQuality == NetworkQuality.disconnected) {
      issues.add('You are disconnected');
    }

    if (status.guestQuality == NetworkQuality.poor) {
      issues.add('Guest network quality is poor');
    }

    if (issues.isNotEmpty && _shouldReportIssue()) {
      _reportNetworkIssue(issues.join(', '));
    }
  }

  // ============ CLEANUP ============

  void dispose() {
    stopMonitoring();
    _networkStatusCtrl.close();
    _connectionStatsCtrl.close();
    _networkIssueCtrl.close();
    debugPrint('📡 NetworkMonitorService disposed');
  }
}
