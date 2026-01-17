// lib/features/live_viewer/presentation/services/reconnection_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';

enum ReconnectionPhase {
  idle,
  detecting,
  attempting,
  succeeded,
  failed,
  gaveUp,
}

class ReconnectionStatus {
  final ReconnectionPhase phase;
  final int attempt;
  final int maxAttempts;
  final String? message;
  final DateTime timestamp;
  final Duration? nextRetryIn;

  const ReconnectionStatus({
    required this.phase,
    this.attempt = 0,
    this.maxAttempts = 0,
    this.message,
    required this.timestamp,
    this.nextRetryIn,
  });

  bool get isActive => phase == ReconnectionPhase.attempting;
  bool get isSuccessful => phase == ReconnectionPhase.succeeded;
  bool get isFailed => phase == ReconnectionPhase.failed;
  bool get gaveUp => phase == ReconnectionPhase.gaveUp;
}

/// Handles automatic reconnection with exponential backoff
class ReconnectionService {
  final LiveStreamService _liveStreamService;
  final StreamController<ReconnectionStatus> _statusCtrl =
      StreamController.broadcast();

  ReconnectionPhase _currentPhase = ReconnectionPhase.idle;
  int _currentAttempt = 0;
  int _maxAttempts = 5;
  Timer? _retryTimer;
  Timer? _detectionTimer;
  bool _isMonitoring = false;

  // State preservation
  Map<String, dynamic>? _savedState;
  DateTime? _connectionLostTime;

  ReconnectionService(this._liveStreamService);

  // ============ PUBLIC API ============

  Stream<ReconnectionStatus> watchReconnection() => _statusCtrl.stream;

  ReconnectionStatus get currentStatus => ReconnectionStatus(
    phase: _currentPhase,
    attempt: _currentAttempt,
    maxAttempts: _maxAttempts,
    timestamp: DateTime.now(),
  );

  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    debugPrint('🔄 Starting reconnection monitoring');

    // Monitor connection state
    _liveStreamService.watchConnectionState().listen((state) {
      if (state == ConnectionState.disconnected &&
          _currentPhase == ReconnectionPhase.idle) {
        _onConnectionLost();
      } else if (state == ConnectionState.connected &&
          _currentPhase == ReconnectionPhase.attempting) {
        _onReconnected();
      }
    });

    // Periodic detection for missed events
    _detectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkConnectionHealth(),
    );
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _detectionTimer?.cancel();
    _detectionTimer = null;
    _cancelRetry();
    debugPrint('🔄 Stopped reconnection monitoring');
  }

  Future<void> attemptReconnection() async {
    if (_currentPhase == ReconnectionPhase.attempting) {
      debugPrint('⚠️ Reconnection already in progress');
      return;
    }

    _currentPhase = ReconnectionPhase.attempting;
    _currentAttempt = 0;
    _maxAttempts = 5;

    _emitStatus('Starting reconnection...');

    await _performReconnectionAttempt();
  }

  Future<void> saveCurrentState() async {
    // Save critical state that needs to be preserved
    _savedState = {
      'timestamp': DateTime.now().toIso8601String(),
      'isGuest': _liveStreamService.isGuest,
      'isCoHost': _liveStreamService.isCoHost,
      // Add more state as needed
    };

    debugPrint('💾 Saved connection state for recovery');
  }

  Future<void> restoreState() async {
    if (_savedState == null) {
      debugPrint('⚠️ No saved state to restore');
      return;
    }

    debugPrint('🔄 Restoring saved connection state');

    // TODO: Restore Agora state based on saved state
    // This would involve rejoining with appropriate role

    _savedState = null;
  }

  // ============ PRIVATE METHODS ============

  void _onConnectionLost() {
    debugPrint('🔌 Connection lost detected');

    _connectionLostTime = DateTime.now();
    _currentPhase = ReconnectionPhase.detecting;
    _currentAttempt = 0;

    _emitStatus('Connection lost. Preparing to reconnect...');

    // Save state before attempting reconnection
    saveCurrentState();

    // Start reconnection after short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (_currentPhase == ReconnectionPhase.detecting) {
        _startReconnectionAttempt();
      }
    });
  }

  void _onReconnected() {
    if (_currentPhase == ReconnectionPhase.attempting) {
      debugPrint('✅ Reconnection successful');

      _currentPhase = ReconnectionPhase.succeeded;
      _cancelRetry();

      _emitStatus('Reconnected successfully!');

      // Restore saved state
      restoreState();

      // Reset after success
      Future.delayed(const Duration(seconds: 2), () {
        if (_currentPhase == ReconnectionPhase.succeeded) {
          _currentPhase = ReconnectionPhase.idle;
          _emitStatus(null);
        }
      });
    }
  }

  Future<void> _startReconnectionAttempt() async {
    _currentPhase = ReconnectionPhase.attempting;
    _currentAttempt = 1;
    _maxAttempts = 5;

    await _performReconnectionAttempt();
  }

  Future<void> _performReconnectionAttempt() async {
    while (_currentAttempt <= _maxAttempts &&
        _currentPhase == ReconnectionPhase.attempting) {
      final delay = _calculateBackoffDelay(_currentAttempt);
      final isLastAttempt = _currentAttempt == _maxAttempts;

      _emitStatus(
        'Reconnecting (attempt $_currentAttempt/$_maxAttempts)...',
        nextRetryIn: isLastAttempt ? null : delay,
      );

      if (_currentAttempt > 1) {
        debugPrint(
          '⏳ Waiting ${delay.inSeconds}s before attempt $_currentAttempt...',
        );
        await Future.delayed(delay);
      }

      try {
        debugPrint('🔌 Attempting reconnection #$_currentAttempt...');
        await _liveStreamService.reconnect();

        // If we get here, reconnection succeeded
        return;
      } catch (e) {
        debugPrint('❌ Reconnection attempt $_currentAttempt failed: $e');

        if (isLastAttempt) {
          _currentPhase = ReconnectionPhase.gaveUp;
          _emitStatus(
            'Failed to reconnect after $_maxAttempts attempts. '
            'Please check your network connection.',
          );
          break;
        }

        _currentAttempt++;
      }
    }

    if (_currentPhase == ReconnectionPhase.attempting) {
      _currentPhase = ReconnectionPhase.failed;
      _emitStatus('Reconnection failed unexpectedly');
    }
  }

  Duration _calculateBackoffDelay(int attempt) {
    // Exponential backoff with jitter: base * 2^(attempt-1) ± random
    const baseDelay = Duration(seconds: 1);
    final exponential = baseDelay * pow(2, attempt - 1);

    // Add ±20% jitter to prevent thundering herd
    final jitter = exponential.inMilliseconds * 0.2;
    final randomJitter = Random().nextDouble() * jitter * 2 - jitter;

    final delayMs = exponential.inMilliseconds + randomJitter;
    return Duration(
      milliseconds: delayMs.clamp(1000, 30000).toInt(),
    ); // Min 1s, Max 30s
  }

  void _checkConnectionHealth() {
    if (!_isMonitoring) return;

    // Check if we think we're connected but service says otherwise
    final isActuallyConnected = _liveStreamService.isJoined;

    if (!isActuallyConnected && _currentPhase == ReconnectionPhase.idle) {
      debugPrint('🩺 Connection health check failed - triggering reconnection');
      _onConnectionLost();
    }
  }

  void _emitStatus(String? message, {Duration? nextRetryIn}) {
    final status = ReconnectionStatus(
      phase: _currentPhase,
      attempt: _currentAttempt,
      maxAttempts: _maxAttempts,
      message: message,
      timestamp: DateTime.now(),
      nextRetryIn: nextRetryIn,
    );

    _statusCtrl.add(status);
    debugPrint('🔄 Reconnection Status: $message');
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  // ============ CLEANUP ============

  void dispose() {
    stopMonitoring();
    _cancelRetry();
    _statusCtrl.close();
    debugPrint('🔄 ReconnectionService disposed');
  }
}
