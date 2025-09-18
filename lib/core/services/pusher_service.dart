import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

typedef PusherCallback = void Function(Map<String, dynamic> payload);

/// Thin wrapper around pusher_channels_flutter (v2.5.1) that:
/// - Initializes once with your key/cluster
/// - Manages subscriptions
/// - Lets you register per-channel, per-event callbacks (like channel.bind)
/// - Routes PusherEvent -> your callbacks with JSON parsing
class PusherService {
  final String apiKey;
  final String cluster;

  // Optional: if later you need private/presence channels, wire these.
  final String? authEndpoint;
  final dynamic Function(String channelName, String socketId, dynamic options)?
  onAuthorizer;

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  bool _initialized = false;
  bool _connected = false;

  // Track what we subscribed to
  final Set<String> _subscriptions = <String>{};
  final Set<String> _subscribing = <String>{}; // ✅ NEW
  Future<void>? _connectFuture; // ✅ NEW
  // Handlers[channel][event] = [callbacks...]
  final Map<String, Map<String, List<PusherCallback>>> _handlers = {};

  PusherService({
    required this.apiKey,
    required this.cluster,
    this.authEndpoint,
    this.onAuthorizer,
  });

  /// Initialize the Pusher instance in the 2.5.1 style.
  Future<void> _initIfNeeded() async {
    if (_initialized) return;

    await _pusher.init(
      apiKey: apiKey,
      cluster: cluster,
      onConnectionStateChange: _onConnectionStateChange,
      onError: _onError,
      onSubscriptionSucceeded: _onSubscriptionSucceeded,
      onEvent: _onEvent,
      onSubscriptionError: _onSubscriptionError,
      onDecryptionFailure: _onDecryptionFailure,
      onMemberAdded: _onMemberAdded,
      onMemberRemoved: _onMemberRemoved,
      onSubscriptionCount: _onSubscriptionCount,
      authEndpoint: authEndpoint,
      onAuthorizer: onAuthorizer,
    );

    _initialized = true;
  }

  Future<void> connect() async {
    await _initIfNeeded();
    if (_connected) return;
    _connectFuture ??= _pusher.connect();
    await _connectFuture;
    _connected = true;
  }

  Future<void> subscribe(String channelName) async {
    await connect();
    if (_subscriptions.contains(channelName) ||
        _subscribing.contains(channelName)) {
      return; // ✅ no-op if already (being) subscribed
    }
    _subscribing.add(channelName);
    try {
      await _pusher.subscribe(channelName: channelName);
      _subscriptions.add(channelName);
    } on PlatformException catch (e) {
      // Treat "Already subscribed" as success
      if ((e.message ?? '').contains('Already subscribed')) {
        _subscriptions.add(channelName);
      } else {
        rethrow;
      }
    } finally {
      _subscribing.remove(channelName);
    }
  }

  /// Register a handler for a channel+event (similar to channel.bind).
  void bind(String channelName, String eventName, PusherCallback cb) {
    final events = _handlers.putIfAbsent(channelName, () => {});
    final list = events.putIfAbsent(eventName, () => <PusherCallback>[]);
    list.add(cb);
  }

  /// Optional unbind, if you need it.
  void unbind(String channelName, String eventName, PusherCallback cb) {
    final evs = _handlers[channelName];
    if (evs == null) return;
    final list = evs[eventName];
    list?.remove(cb);
  }

  Future<void> unsubscribeAll() async {
    for (final ch in _subscriptions.toList()) {
      await _pusher.unsubscribe(channelName: ch);
    }
    _subscribing.clear();
    _subscriptions.clear();
    _handlers.clear();
  }

  Future<void> disconnect() async {
    await unsubscribeAll();
    await _pusher.disconnect();
    _connected = false;
    _initialized = false;
    _connectFuture = null; // ✅ IMPORTANT: allow a fresh connect next time
  }

  // ===== Pusher callbacks (from the plugin) =====

  void _onConnectionStateChange(dynamic currentState, dynamic previousState) {
    // Useful for logging if needed
    // debugPrint('Pusher connection: $previousState -> $currentState');
  }

  void _onError(String message, int? code, dynamic e) {
    // debugPrint('Pusher error: $message ($code) ex=$e');
    debugPrint('Pusher error: $message ($code) ex=$e');
    _connected = false; // ✅
    _connectFuture = null; // ✅ next connect() will actually reconnect
  }

  void _onSubscriptionSucceeded(String channelName, dynamic data) {
    // debugPrint('Pusher subscribed: $channelName data=$data');
  }

  void _onSubscriptionError(String message, dynamic e) {
    // debugPrint('Pusher sub error: $message ex=$e');
  }

  void _onDecryptionFailure(String event, String reason) {
    // debugPrint('Pusher decrypt fail: $event reason=$reason');
  }

  void _onMemberAdded(String channelName, PusherMember member) {
    // Presence channel only. Not used for public live.* channels today.
  }

  void _onMemberRemoved(String channelName, PusherMember member) {
    // Presence channel only. Not used for public live.* channels today.
  }

  void _onSubscriptionCount(String channelName, int subscriptionCount) {
    // Presence channel only. Not used now.
  }

  void _onEvent(PusherEvent event) {
    // Route to registered callbacks
    final ch = event.channelName;
    final name = event.eventName;

    final cbList = _handlers[ch]?[name];
    if (cbList == null || cbList.isEmpty) return;

    final payload = _asMap(event.data);
    for (final cb in cbList) {
      cb(payload);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final decoded = json.decode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return <String, dynamic>{};
  }
}
