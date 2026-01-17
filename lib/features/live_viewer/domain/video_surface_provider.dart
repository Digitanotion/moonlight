// lib/features/live_viewer/domain/video_surface_provider.dart - ENHANCED
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:moonlight/features/live_viewer/domain/entities.dart';

abstract class VideoSurfaceProvider {
  // Host video
  ValueListenable<bool> get hostHasVideo;
  Widget buildHostVideo();

  // Guest video (when you are not the guest)
  ValueListenable<bool> get guestHasVideo;
  Widget? buildGuestVideo();

  // Local preview (when you are the guest)
  Widget? buildLocalPreview();

  // Guest controls
  Future<void> setMicEnabled(bool enabled);
  Future<void> setCamEnabled(bool enabled);

  // Network monitoring (NEW)
  Stream<NetworkQuality> watchHostNetworkQuality();
  Stream<NetworkQuality> watchSelfNetworkQuality();
  Stream<NetworkQuality>? watchGuestNetworkQuality();

  // Connection state (NEW)
  Stream<ConnectionState> watchConnectionState();

  // Stats (NEW)
  Future<ConnectionStats> getConnectionStats();

  // Reconnection (NEW)
  Future<void> reconnect();
  Future<void> leave();

  // State
  bool get isJoined;
  bool get isGuest;
  bool get isCoHost;

  // Debug
  void debugState();
}
