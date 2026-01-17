// import 'dart:async';
// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

// typedef PusherCallback = void Function(Map<String, dynamic> payload);

// /// Thin wrapper around pusher_channels_flutter (v2.5.1) that:
// /// - Initializes once with your key/cluster
// /// - Manages subscriptions
// /// - Lets you register per-channel, per-event callbacks (like channel.bind)
// /// - Routes PusherEvent -> your callbacks with JSON parsing
// class HostPusherService {
//   final String apiKey;
//   final String cluster;

//   // Optional: if later you need private/presence channels, wire these.
//   final String? authEndpoint;
//   final dynamic Function(String channelName, String socketId, dynamic options)?
//   onAuthorizer;

//   final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

//   bool _initialized = false;
//   bool _connected = false;
//   // Tracks what the app *wants* (sticky across reconnects)
//   final Set<String> _desired = <String>{};

//   // Tracks what the SDK is *actually* subscribed to right now
//   final Set<String> _active = <String>{};
//   // Track what we subscribed to
//   final Set<String> _subscriptions = <String>{};
//   final Set<String> _subscribing = <String>{}; // ✅ NEW
//   Future<void>? _connectFuture; // ✅ NEW
//   // Handlers[channel][event] = [callbacks...]
//   final Map<String, Map<String, List<PusherCallback>>> _handlers = {};

//   HostPusherService({
//     required this.apiKey,
//     required this.cluster,
//     this.authEndpoint,
//     this.onAuthorizer,
//   });

//   /// Initialize the Pusher instance in the 2.5.1 style.
//   Future<void> _initIfNeeded() async {
//     if (_initialized) return;

//     await _pusher.init(
//       apiKey: apiKey,
//       cluster: cluster,
//       onConnectionStateChange: _onConnectionStateChange,
//       onError: _onError,
//       onSubscriptionSucceeded: _onSubscriptionSucceeded,
//       onEvent: _onEvent,
//       onSubscriptionError: _onSubscriptionError,
//       onDecryptionFailure: _onDecryptionFailure,
//       onMemberAdded: _onMemberAdded,
//       onMemberRemoved: _onMemberRemoved,
//       onSubscriptionCount: _onSubscriptionCount,
//       authEndpoint: authEndpoint,
//       onAuthorizer: onAuthorizer,
//     );

//     _initialized = true;
//   }

//   Future<void> connect() async {
//     await _initIfNeeded();
//     if (_connected) return;
//     _connectFuture ??= _pusher.connect();
//     await _connectFuture;
//     // _connected = true;
//   }

//   Future<void> subscribe(String channelName) async {
//     // Mark sticky intent first so reconnect can replay this later
//     _desired.add(channelName);

//     await connect();

//     // If already active or in the middle of subscribing, no-op
//     if (_active.contains(channelName) || _subscribing.contains(channelName)) {
//       return;
//     }

//     _subscribing.add(channelName);
//     try {
//       await _pusher.subscribe(channelName: channelName);
//       _active.add(channelName);
//     } on PlatformException catch (e) {
//       if ((e.message ?? '').contains('Already subscribed')) {
//         _active.add(channelName);
//       } else {
//         rethrow;
//       }
//     } finally {
//       _subscribing.remove(channelName);
//     }
//   }

//   /// Subscribe many at once (handy for replay)
//   Future<void> subscribeMany(Iterable<String> channels) async {
//     for (final ch in channels) {
//       try {
//         await subscribe(ch);
//       } catch (_) {
//         // keep going per-channel
//       }
//     }
//   }

//   /// Unsubscribe only channels that start with [prefix]
//   Future<void> unsubscribePrefix(String prefix) async {
//     final toDrop = _active.where((c) => c.startsWith(prefix)).toList();
//     for (final ch in toDrop) {
//       try {
//         await _pusher.unsubscribe(channelName: ch);
//       } catch (_) {}
//       _active.remove(ch);
//       _desired.remove(ch);
//       _handlers.remove(ch);
//     }
//   }

//   /// Register a handler for a channel+event (similar to channel.bind).
//   void bind(String channelName, String eventName, PusherCallback cb) {
//     final events = _handlers.putIfAbsent(channelName, () => {});
//     final list = events.putIfAbsent(eventName, () => <PusherCallback>[]);
//     list.add(cb);
//   }

//   /// Optional unbind, if you need it.
//   void unbind(String channelName, String eventName, PusherCallback cb) {
//     final evs = _handlers[channelName];
//     if (evs == null) return;
//     final list = evs[eventName];
//     list?.remove(cb);
//   }

//   Future<void> unsubscribeAll() async {
//     for (final ch in _active.toList()) {
//       try {
//         await _pusher.unsubscribe(channelName: ch);
//       } catch (_) {}
//     }
//     _subscribing.clear();
//     _active.clear();
//     _desired.clear();
//     _handlers.clear();
//   }

//   Future<void> disconnect() async {
//     // Keep desired? Usually a full disconnect is a teardown,
//     // so we clear both to avoid accidental replay later.
//     await unsubscribeAll();
//     await _pusher.disconnect();
//     _connected = false;
//     _initialized = false;
//     _connectFuture = null;
//   }

//   // ===== Pusher callbacks (from the plugin) =====

//   void _onConnectionStateChange(dynamic currentState, dynamic previousState) {
//     // States come as strings like "CONNECTING", "CONNECTED", "DISCONNECTED"
//     final s = (currentState ?? '').toString().toUpperCase();
//     if (s == 'CONNECTED') {
//       _connected = true;

//       // On reconnect, the SDK loses all channel subscriptions.
//       // Replay intent for any desired channel that isn't active.
//       // (Active set may be wrong after a reconnect; ensure it's rebuilt.)
//       // Reset active to force replay, then subscribe desired.
//       _active.clear();

//       // Fire-and-forget; this repopulates _active on success
//       // but don't await inside callback chain.
//       // If you prefer, you can ignore the returned Future.
//       // Triggering serially is fine for the small number of channels we use.
//       subscribeMany(_desired);
//     } else if (s == 'DISCONNECTED') {
//       _connected = false;
//       _connectFuture = null; // allow fresh connect next time
//       // Keep _desired so we can replay on next CONNECTED
//       _active.clear();
//     }
//   }

//   void _onError(String message, int? code, dynamic e) {
//     // debugPrint('Pusher error: $message ($code) ex=$e');
//     debugPrint('Pusher error: $message ($code) ex=$e');
//     _connected = false; // ✅
//     _connectFuture = null; // ✅ next connect() will actually reconnect
//   }

//   void _onSubscriptionSucceeded(String channelName, dynamic data) {
//     _active.add(channelName); // mark as active (reconnect path)
//   }

//   void _onSubscriptionError(String message, dynamic e) {
//     // debugPrint('Pusher sub error: $message ex=$e');
//   }

//   void _onDecryptionFailure(String event, String reason) {
//     // debugPrint('Pusher decrypt fail: $event reason=$reason');
//   }

//   void _onMemberAdded(String channelName, PusherMember member) {
//     // Presence channel only. Not used for public live.* channels today.
//   }

//   void _onMemberRemoved(String channelName, PusherMember member) {
//     // Presence channel only. Not used for public live.* channels today.
//   }

//   void _onSubscriptionCount(String channelName, int subscriptionCount) {
//     // Presence channel only. Not used now.
//   }

//   void _onEvent(PusherEvent event) {
//     // Route to registered callbacks
//     final ch = event.channelName;
//     final name = event.eventName;

//     final cbList = _handlers[ch]?[name];
//     if (cbList == null || cbList.isEmpty) return;

//     final payload = _asMap(event.data);
//     for (final cb in cbList) {
//       cb(payload);
//     }
//   }

//   Map<String, dynamic> _asMap(dynamic data) {
//     if (data is Map<String, dynamic>) return data;
//     if (data is String) {
//       try {
//         final decoded = json.decode(data);
//         if (decoded is Map<String, dynamic>) return decoded;
//       } catch (_) {}
//     }
//     return <String, dynamic>{};
//   }
// }
