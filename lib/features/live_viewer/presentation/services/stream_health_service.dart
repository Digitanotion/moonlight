// lib/features/live_viewer/presentation/services/stream_health_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:moonlight/core/network/dio_client.dart';

enum StreamHealthStatus { unknown, online, unstable, offline, premiumRequired }

class StreamHealthResult {
  final StreamHealthStatus status;
  final bool isPremium;
  final bool hasPaidPremium;
  final int? entryFeeCoins;
  final String? message;

  const StreamHealthResult({
    required this.status,
    this.isPremium = false,
    this.hasPaidPremium = false,
    this.entryFeeCoins,
    this.message,
  });
}

/// Periodically polls /status (and /premium/status when needed).
///
/// Premium lifecycle handled:
///   free → premium:     detected on next poll, checks /premium/status,
///                       emits [premiumRequired] if user hasn't paid.
///   premium (unpaid)  → user pays → call [onPremiumGranted] →
///                       paywall cleared, polling continues normally.
///   premium → free:     detected when is_premium flips to false,
///                       resets internal state, emits [online] to clear
///                       any active paywall overlay.
///   premium re-enable:  detected again on next poll after cancellation
///                       because [_premiumAccessConfirmed] was reset.
class StreamHealthService {
  final DioClient http;
  final String livestreamUuid;
  final Duration pollInterval;

  StreamHealthService({
    required this.http,
    required this.livestreamUuid,
    this.pollInterval = const Duration(seconds: 12),
  });

  final _controller = StreamController<StreamHealthResult>.broadcast();
  Stream<StreamHealthResult> get stream => _controller.stream;

  Timer? _timer;
  StreamHealthStatus _lastEmittedStatus = StreamHealthStatus.unknown;
  bool _disposed = false;

  // Whether the current viewer has confirmed premium payment.
  // Reset when host cancels premium so future re-enables are detected.
  bool _premiumAccessConfirmed = false;

  // Track whether the stream was premium on the last successful poll,
  // so we can detect the host cancelling premium mid-session.
  bool _wasLastPollPremium = false;

  // Consecutive error counter — avoids false unstable alarms.
  int _consecutiveFailures = 0;
  static const int _failureThreshold = 2;

  // ── Public API ────────────────────────────────────────────────────────────

  void start() {
    if (_disposed) return;
    _check();
    _timer = Timer.periodic(pollInterval, (_) => _check());
    debugPrint(
      '🏥 StreamHealthService: started (interval: ${pollInterval.inSeconds}s)',
    );
  }

  /// Call this when the viewer successfully pays for premium access.
  /// Stops the service from re-triggering the paywall on subsequent polls.
  void onPremiumGranted() {
    _premiumAccessConfirmed = true;
    debugPrint('🏥 StreamHealthService: premium access confirmed by viewer');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('🏥 StreamHealthService: stopped');
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
    if (!_controller.isClosed) _controller.close();
    debugPrint('🏥 StreamHealthService: disposed');
  }

  // ── Poll logic ────────────────────────────────────────────────────────────

  Future<void> _check() async {
    if (_disposed || _controller.isClosed) return;

    try {
      final statusResult = await _fetchStreamStatus();
      if (_disposed || _controller.isClosed) return;

      // ── Stream ended ──────────────────────────────────────────────────────
      if (statusResult.status == StreamHealthStatus.offline) {
        _emit(statusResult);
        stop();
        return;
      }

      // ── Host CANCELLED premium (was premium last poll, now free) ──────────
      // Detect: previous poll was premium AND now is_premium = false.
      if (_wasLastPollPremium && !statusResult.isPremium) {
        debugPrint(
          '🏥 StreamHealthService: host cancelled premium — clearing paywall',
        );
        // Reset so future re-enables are detected.
        _premiumAccessConfirmed = false;
        // Force _emit to fire even if status hasn't changed from online,
        // so the BLoC receives the signal to clear the paywall.
        _lastEmittedStatus = StreamHealthStatus.unknown;
        _wasLastPollPremium = false;
        _emit(
          statusResult,
        ); // emits online → BLoC clears requiresPremiumPayment
        return;
      }

      // ── Stream is premium and user hasn't paid yet ────────────────────────
      if (statusResult.isPremium && !_premiumAccessConfirmed) {
        _wasLastPollPremium = true;
        final premiumResult = await _fetchPremiumAccess();
        if (!_disposed && !_controller.isClosed) {
          _emit(premiumResult);
        }
        return;
      }

      // ── Normal online ─────────────────────────────────────────────────────
      _wasLastPollPremium = statusResult.isPremium;
      _emit(statusResult);
    } catch (e) {
      debugPrint('🏥 StreamHealthService: poll error: $e');
    }
  }

  // ── API calls ─────────────────────────────────────────────────────────────

  Future<StreamHealthResult> _fetchStreamStatus() async {
    try {
      final res = await http.dio
          .get('/api/v1/live/$livestreamUuid/status')
          .timeout(const Duration(seconds: 8));

      final data = _asMap(res.data);
      final rawStatus = (data['status'] ?? '').toString().toLowerCase();
      final isPremium = data['is_premium'] == true;
      final entryFee = (data['entry_fee_coins'] as num?)?.toInt() ?? 0;

      _consecutiveFailures = 0;

      switch (rawStatus) {
        case 'online':
          return StreamHealthResult(
            status: StreamHealthStatus.online,
            isPremium: isPremium,
            entryFeeCoins: entryFee,
          );
        case 'offline':
        case 'ended':
          return StreamHealthResult(
            status: StreamHealthStatus.offline,
            message: (data['message'] as String?) ?? 'Stream has ended.',
            isPremium: isPremium,
          );
        default:
          _consecutiveFailures++;
          return StreamHealthResult(
            status: _consecutiveFailures >= _failureThreshold
                ? StreamHealthStatus.unstable
                : StreamHealthStatus.online,
            isPremium: isPremium,
            message: 'Stream quality is degraded.',
          );
      }
    } catch (e) {
      _consecutiveFailures++;
      debugPrint('🏥 _fetchStreamStatus error: $e');
      if (_consecutiveFailures >= _failureThreshold) {
        return const StreamHealthResult(
          status: StreamHealthStatus.unstable,
          message: 'Having trouble reaching the stream.',
        );
      }
      return StreamHealthResult(status: _lastEmittedStatus);
    }
  }

  Future<StreamHealthResult> _fetchPremiumAccess() async {
    try {
      final res = await http.dio
          .get('/api/v1/live/$livestreamUuid/premium/status')
          .timeout(const Duration(seconds: 8));

      final data = _asMap(res.data);
      final inner = _asMap(data['data']);

      final canAccess =
          inner['can_access'] == true ||
          inner['has_paid'] == true ||
          inner['already_purchased'] == true;
      final entryFee = (inner['entry_fee_coins'] as num?)?.toInt() ?? 0;

      if (canAccess) {
        _premiumAccessConfirmed = true;
      }

      return StreamHealthResult(
        status: canAccess
            ? StreamHealthStatus.online
            : StreamHealthStatus.premiumRequired,
        isPremium: true,
        hasPaidPremium: canAccess,
        entryFeeCoins: entryFee,
      );
    } catch (e) {
      debugPrint('🏥 _fetchPremiumAccess error: $e');
      // On network error, don't lock the user out.
      return const StreamHealthResult(
        status: StreamHealthStatus.online,
        isPremium: true,
        hasPaidPremium: true,
      );
    }
  }

  // ── Emit ──────────────────────────────────────────────────────────────────

  void _emit(StreamHealthResult result) {
    if (result.status != _lastEmittedStatus) {
      debugPrint(
        '🏥 StreamHealthService: ${_lastEmittedStatus.name} → ${result.status.name}',
      );
      _lastEmittedStatus = result.status;
      if (!_controller.isClosed) {
        _controller.add(result);
      }
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
