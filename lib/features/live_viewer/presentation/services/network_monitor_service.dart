// lib/features/live_viewer/presentation/services/network_monitor_service.dart
//
// CHANGES vs original:
//   1. Added _disposed flag — all add() calls guarded by isClosed checks.
//   2. _performMonitoringCycle: returns early if any controller is closed.
//   3. _reportNetworkIssue: guards _networkIssueCtrl.isClosed.
//   4. _onConnectionStateChanged: guards before adding.
//   Everything else identical.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';

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
  bool _disposed = false; // ← NEW

  NetworkMonitorService(this._liveStreamService);

  // ============ PUBLIC API ============

  Stream<NetworkStatus> watchNetworkStatus() => _networkStatusCtrl.stream;
  Stream<ConnectionStats> watchConnectionStats() => _connectionStatsCtrl.stream;
  Stream<String> watchNetworkIssues() => _networkIssueCtrl.stream;

  void startMonitoring() {
    if (_monitoringTimer != null) return;
    if (_disposed) return; // ← NEW

    debugPrint('📡 Starting network monitoring');

    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _performMonitoringCycle(),
    );

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
    if (_disposed) return; // ← NEW
    _reportNetworkIssue('Optimizing network connection...');
    await Future.delayed(const Duration(seconds: 1));
    _reportNetworkIssue('Network optimization completed');
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
    // ← NEW: bail out immediately if disposed
    if (_disposed ||
        _networkStatusCtrl.isClosed ||
        _connectionStatsCtrl.isClosed ||
        _networkIssueCtrl.isClosed) {
      stopMonitoring();
      return;
    }

    try {
      final status = await getCurrentStatus();

      if (_disposed || _networkStatusCtrl.isClosed) return; // ← NEW
      _networkStatusCtrl.add(status);

      if (DateTime.now().second % 10 == 0) {
        final stats = await _liveStreamService.getConnectionStats();
        if (_disposed || _connectionStatsCtrl.isClosed) return; // ← NEW
        _connectionStatsCtrl.add(stats);
      }

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
    if (_disposed || _networkIssueCtrl.isClosed) return; // ← NEW
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
    if (_disposed || _networkIssueCtrl.isClosed) return; // ← NEW
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
    return DateTime.now().difference(_lastIssueReported!).inSeconds > 30;
  }

  void _reportNetworkIssue(String message) {
    if (_disposed || _networkIssueCtrl.isClosed) return; // ← NEW
    _lastIssueReported = DateTime.now();
    _networkIssueCtrl.add(message);
    debugPrint('⚠️ Network Issue: $message');
  }

  Future<NetworkQuality> _getCurrentHostQuality() async => _lastHostQuality;
  Future<NetworkQuality> _getCurrentSelfQuality() async => _lastSelfQuality;
  Future<NetworkQuality?> _getCurrentGuestQuality() async {
    if (_liveStreamService.isGuest) return _lastGuestQuality;
    return null;
  }

  Future<void> _detectNetworkIssues(NetworkStatus status) async {
    if (_disposed || _networkIssueCtrl.isClosed) return; // ← NEW
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
    _disposed = true; // ← NEW: set before closing controllers
    stopMonitoring();
    _networkStatusCtrl.close();
    _connectionStatsCtrl.close();
    _networkIssueCtrl.close();
    debugPrint('📡 NetworkMonitorService disposed');
  }
}
