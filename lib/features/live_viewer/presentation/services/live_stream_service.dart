// lib/features/live_viewer/presentation/services/live_stream_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/domain/video_surface_provider.dart';

/// Handles ALL video/audio operations, extracted from repository
class LiveStreamService with ChangeNotifier implements VideoSurfaceProvider {
  final AgoraViewerService _agoraService;
  final TokenRefresher _tokenRefresher;

  // State
  final ValueNotifier<bool> _hostHasVideo = ValueNotifier(false);
  final ValueNotifier<bool> _guestHasVideo = ValueNotifier(false);
  final ValueNotifier<NetworkQuality> _hostNetworkQuality = ValueNotifier(
    NetworkQuality.unknown,
  );
  final ValueNotifier<NetworkQuality> _selfNetworkQuality = ValueNotifier(
    NetworkQuality.unknown,
  );
  final ValueNotifier<NetworkQuality?> _guestNetworkQuality = ValueNotifier(
    null,
  );
  final ValueNotifier<ConnectionState> _connectionState = ValueNotifier(
    ConnectionState.disconnected,
  );

  // Stream controllers for network monitoring
  final StreamController<NetworkQuality> _hostQualityCtrl =
      StreamController.broadcast();
  final StreamController<NetworkQuality> _selfQualityCtrl =
      StreamController.broadcast();
  final StreamController<NetworkQuality> _guestQualityCtrl =
      StreamController.broadcast();
  final StreamController<ConnectionState> _connectionStateCtrl =
      StreamController.broadcast();

  // Timer for periodic stats collection
  Timer? _networkMonitorTimer;

  LiveStreamService({
    required AgoraViewerService agoraService,
    required TokenRefresher tokenRefresher,
  }) : _agoraService = agoraService,
       _tokenRefresher = tokenRefresher {
    _setupNetworkMonitoring();
    _setupConnectionStateMonitoring();
  }

  // ============ VIDEO SURFACE PROVIDER IMPLEMENTATION ============

  @override
  ValueListenable<bool> get hostHasVideo => _hostHasVideo;

  @override
  ValueListenable<bool> get guestHasVideo => _guestHasVideo;

  bool get isAgoraJoined => _agoraService.isJoined;
  ConnectionState get agoraConnectionState =>
      _agoraService.connectionState.value;

  @override
  Widget buildHostVideo() {
    // if (_agoraService.engine == null || !_agoraService.isJoined) {
    //   // return _buildConnectingPlaceholder('Connecting to stream...');
    // }
    debugPrint("User joined and engine has built video ");
    return _agoraService.buildHostVideo();
  }

  // Widget _buildConnectingPlaceholder(String message) {
  //   return Container(
  //     color: AppColors.dark,
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         const CircularProgressIndicator(),
  //         const SizedBox(height: 16),
  //         Text(
  //           message,
  //           style: const TextStyle(color: Colors.white70, fontSize: 14),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget? buildGuestVideo() {
    return _agoraService.buildGuestVideo();
  }

  @override
  Widget? buildLocalPreview() {
    return _agoraService.buildLocalPreview();
  }

  @override
  Future<void> setMicEnabled(bool enabled) async {
    await _agoraService.setMicEnabled(enabled);
    notifyListeners();
  }

  @override
  Future<void> setCamEnabled(bool enabled) async {
    await _agoraService.setCamEnabled(enabled);
    notifyListeners();
  }

  // ============ NETWORK MONITORING IMPLEMENTATION ============

  @override
  Stream<NetworkQuality> watchHostNetworkQuality() => _hostQualityCtrl.stream;

  @override
  Stream<NetworkQuality> watchSelfNetworkQuality() => _selfQualityCtrl.stream;

  @override
  Stream<NetworkQuality>? watchGuestNetworkQuality() {
    return _agoraService.guestUid.value != null
        ? _guestQualityCtrl.stream
        : null;
  }

  @override
  Stream<ConnectionState> watchConnectionState() => _connectionStateCtrl.stream;

  @override
  Future<ConnectionStats> getConnectionStats() async {
    // TODO: Implement actual Agora stats collection
    return ConnectionStats(
      bitrate: 1500,
      packetLoss: 2,
      latency: 120,
      jitter: 30,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> reconnect() async {
    _connectionState.value = ConnectionState.reconnecting;
    _connectionStateCtrl.add(ConnectionState.reconnecting);

    try {
      // Attempt reconnection logic
      await _agoraService.leave();
      // TODO: Implement proper reconnection with saved state
      _connectionState.value = ConnectionState.connected;
      _connectionStateCtrl.add(ConnectionState.connected);
    } catch (e) {
      _connectionState.value = ConnectionState.failed;
      _connectionStateCtrl.add(ConnectionState.failed);
      rethrow;
    }
  }

  @override
  Future<void> leave() async {
    await _agoraService.leave();
    _connectionState.value = ConnectionState.disconnected;
    _connectionStateCtrl.add(ConnectionState.disconnected);
  }

  @override
  bool get isJoined => _agoraService.isJoined;

  @override
  bool get isGuest => _agoraService.isCoHost;

  @override
  bool get isCoHost => _agoraService.isCoHost;

  // ============ PRIVATE METHODS ============

  void _setupNetworkMonitoring() {
    // Listen to Agora video state changes
    _agoraService.hostHasVideo.addListener(() {
      _hostHasVideo.value = _agoraService.hostHasVideo.value;
    });

    _agoraService.guestHasVideo.addListener(() {
      _guestHasVideo.value = _agoraService.guestHasVideo.value;
    });

    // Start periodic network quality monitoring
    _networkMonitorTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _collectNetworkQuality(),
    );
  }

  void _setupConnectionStateMonitoring() {
    // Map Agora connection states to our domain
    // TODO: Integrate with Agora's onConnectionStateChanged
    _connectionState.value = _agoraService.isJoined
        ? ConnectionState.connected
        : ConnectionState.disconnected;
  }

  Future<void> _collectNetworkQuality() async {
    try {
      // Collect host quality
      final hostQuality = await _estimateNetworkQuality('host');
      _hostNetworkQuality.value = hostQuality;
      _hostQualityCtrl.add(hostQuality);

      // Collect self quality
      final selfQuality = await _estimateNetworkQuality('self');
      _selfNetworkQuality.value = selfQuality;
      _selfQualityCtrl.add(selfQuality);

      // Collect guest quality if available
      if (_agoraService.guestUid.value != null) {
        final guestQuality = await _estimateNetworkQuality('guest');
        _guestNetworkQuality.value = guestQuality;
        _guestQualityCtrl.add(guestQuality);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Network quality collection failed: $e');
    }
  }

  Future<NetworkQuality> _estimateNetworkQuality(String target) async {
    // TODO: Implement actual WebRTC stats collection
    // For now, return simulated data
    await Future.delayed(const Duration(milliseconds: 100));

    final rand = DateTime.now().millisecond % 100;
    return switch (rand) {
      < 20 => NetworkQuality.excellent,
      < 50 => NetworkQuality.good,
      < 80 => NetworkQuality.poor,
      _ => NetworkQuality.disconnected,
    };
  }

  // ============ CLEANUP ============

  @override
  void dispose() {
    _networkMonitorTimer?.cancel();
    _hostQualityCtrl.close();
    _selfQualityCtrl.close();
    _guestQualityCtrl.close();
    _connectionStateCtrl.close();
    super.dispose();
  }

  @override
  void debugState() {
    _agoraService.debugState();
    debugPrint('''
=== LiveStreamService State ===
Host Video: ${_hostHasVideo.value}
Guest Video: ${_guestHasVideo.value}
Host Network: ${_hostNetworkQuality.value}
Self Network: ${_selfNetworkQuality.value}
Guest Network: ${_guestNetworkQuality.value}
Connection State: ${_connectionState.value}
Is Joined: ${isJoined}
Is Guest: ${isGuest}
Is CoHost: ${isCoHost}
=============================''');
  }
}
