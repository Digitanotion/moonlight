// lib/core/services/pusher_service.dart - COMPATIBLE VERSION
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

typedef PusherCallback = void Function(Map<String, dynamic> payload);
typedef PusherAuthCallback =
    Future<Map<String, dynamic>> Function(
      String channelName,
      String socketId,
      Map<String, dynamic> options,
    );

class PusherService {
  final PusherChannelsFlutter _pusher;
  bool _isInitialized = false;
  bool _isConnecting = false;
  ConnectionState _connectionState = ConnectionState.disconnected;

  final List<ValueChanged<ConnectionState>> _connectionListeners = [];
  // final Map<String, List<PusherCallback>> _handlers = {};
  final Map<String, Map<String, List<PusherCallback>>> _handlers = {};
  final Set<String> _desiredChannels = {};
  final Set<String> _activeChannels = {};

  // Configuration
  String? _apiKey;
  String? _cluster;
  String? _authEndpoint;
  PusherAuthCallback? _authCallback;

  PusherService({PusherChannelsFlutter? pusher})
    : _pusher = pusher ?? PusherChannelsFlutter.getInstance();

  /// Initialize Pusher once
  Future<void> initialize({
    required String apiKey,
    required String cluster,
    String? authEndpoint,
    PusherAuthCallback? authCallback,
  }) async {
    if (_isInitialized) {
      debugPrint('⚠️ PusherService already initialized');
      return;
    }

    _apiKey = apiKey;
    _cluster = cluster;
    _authEndpoint = authEndpoint;
    _authCallback = authCallback;

    try {
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
        authEndpoint: authEndpoint,
        onAuthorizer: authCallback != null ? _handleAuthorizer : null,
      );

      _isInitialized = true;
      debugPrint('✅ PusherService initialized');

      await connect();
    } catch (e, stack) {
      debugPrint('❌ Failed to initialize PusherService: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  /// Connect to Pusher
  Future<void> connect() async {
    if (!_isInitialized) {
      throw StateError('PusherService not initialized');
    }

    if (_isConnecting || isConnected) return;

    _isConnecting = true;
    _updateConnectionState(ConnectionState.connecting);

    try {
      await _pusher.connect();
    } catch (e) {
      _isConnecting = false;
      _updateConnectionState(ConnectionState.failed);
      debugPrint('❌ Pusher connection failed: $e');
      rethrow;
    }
  }

  /// Check if Pusher is in a bad state (initialized with 'disabled' key)
  bool get isInBadState {
    return _isInitialized &&
        (_apiKey == 'disabled' || _apiKey == null || _apiKey!.isEmpty);
  }

  /// Fix bad state by reinitializing with proper keys
  Future<void> fixBadState({
    required String apiKey,
    required String cluster,
    String? authEndpoint,
    PusherAuthCallback? authCallback,
  }) async {
    if (!isInBadState) {
      debugPrint('✅ Pusher is not in bad state, skipping fix');
      return;
    }

    debugPrint('🔄 Fixing Pusher bad state...');
    debugPrint('   Old API Key: $_apiKey');
    debugPrint('   New API Key: $apiKey');

    await reinitialize(
      apiKey: apiKey,
      cluster: cluster,
      authEndpoint: authEndpoint,
      authCallback: authCallback,
    );
  }

  /// Disconnect from Pusher
  Future<void> disconnect() async {
    _updateConnectionState(ConnectionState.disconnecting);

    try {
      await _pusher.disconnect();
      _activeChannels.clear();
      _handlers.clear();
      _updateConnectionState(ConnectionState.disconnected);
      debugPrint('✅ Pusher disconnected');
    } catch (e) {
      debugPrint('❌ Pusher disconnect error: $e');
      _updateConnectionState(ConnectionState.failed);
    } finally {
      _isConnecting = false;
    }
  }

  /// Subscribe to channel - COMPATIBLE WITH YOUR CODE
  Future<void> subscribe(String channelName) async {
    if (!_isInitialized) {
      throw StateError('PusherService not initialized');
    }

    _desiredChannels.add(channelName);

    await connect();

    if (_activeChannels.contains(channelName)) {
      return;
    }

    try {
      await _pusher.subscribe(channelName: channelName);
      debugPrint('🔄 Subscribing to channel: $channelName');
    } on PlatformException catch (e) {
      if (e.message?.contains('Already subscribed') == true) {
        _activeChannels.add(channelName);
      } else {
        rethrow;
      }
    }
  }

  /// Subscribe to private channel - FIXED for your chat code
  Future<void> subscribePrivate(String channelName) async {
    // Your code passes: 'private-conversations.$conversationUuid'
    // We need to handle this correctly
    if (channelName.startsWith('private-')) {
      // Already has prefix
      await subscribe(channelName);
    } else {
      // Add prefix
      await subscribe('private-$channelName');
    }
  }

  /// Subscribe to presence channel
  Future<void> subscribePresence(String channelName) async {
    final presenceChannelName = channelName.startsWith('presence-')
        ? channelName
        : 'presence-$channelName';
    await subscribe(presenceChannelName);
  }

  /// Bind event handler - COMPATIBLE
  void bind(String channelName, String eventName, PusherCallback callback) {
    debugPrint('\n🔗 [BIND ATTEMPT]');
    debugPrint('   Channel: "$channelName"');
    debugPrint('   Event: "$eventName"');
    debugPrint('   Callback hash: ${callback.hashCode}');
    debugPrint('   Callback type: ${callback.runtimeType}');

    // Get or create channel map
    final channelMap = _handlers.putIfAbsent(
      channelName,
      () => <String, List<PusherCallback>>{},
    );

    // Get or create event list
    final eventHandlers = channelMap.putIfAbsent(
      eventName,
      () => <PusherCallback>[],
    );

    // Check if handler already exists
    if (!eventHandlers.contains(callback)) {
      eventHandlers.add(callback);
      debugPrint(
        '   ✅ SUCCESS: Bound handler for "$channelName" -> "$eventName"',
      );
      debugPrint('   Total handlers for this event: ${eventHandlers.length}');
    } else {
      debugPrint('   ⚠️ WARNING: Handler already bound');
    }

    // Show current state after binding
    debugPrint('   Current state for channel "$channelName":');
    debugPrint('   Events: ${channelMap.keys.toList()}');

    debugPrint('\n');
  }

  /// Unbind event handler - COMPATIBLE
  void unbind(String channelName, String eventName, PusherCallback callback) {
    final channelMap = _handlers[channelName];
    if (channelMap == null) return;

    final eventHandlers = channelMap[eventName];
    if (eventHandlers == null) return;

    eventHandlers.remove(callback);

    // Clean up empty structures
    if (eventHandlers.isEmpty) {
      channelMap.remove(eventName);
    }
    if (channelMap.isEmpty) {
      _handlers.remove(channelName);
    }
  }

  /// Clear all handlers for a channel - ADDED FOR COMPATIBILITY
  void clearChannelHandlers(String channelName) {
    _handlers.remove(channelName);
    debugPrint('🧹 Cleared all handlers for channel: $channelName');
  }

  /// Unsubscribe from channel - FIXED for your chat code
  Future<void> unsubscribe(String channelName) async {
    _desiredChannels.remove(channelName);

    if (!_activeChannels.contains(channelName)) {
      return;
    }

    try {
      await _pusher.unsubscribe(channelName: channelName);
      _activeChannels.remove(channelName);
      clearChannelHandlers(channelName);
      debugPrint('✅ Unsubscribed from channel: $channelName');
    } on PlatformException catch (e) {
      if (e.message?.contains('not subscribed') == true) {
        _activeChannels.remove(channelName);
      } else {
        rethrow;
      }
    }
  }

  // In PusherService class
  Stream<ConnectionState> get connectionStateStream {
    final controller = StreamController<ConnectionState>();

    void listener(ConnectionState state) {
      if (!controller.isClosed) {
        controller.add(state);
      }
    }

    addConnectionListener(listener);

    // Clean up when stream is closed
    controller.onCancel = () {
      removeConnectionListener(listener);
    };

    return controller.stream;
  }

  // Also add this method to help debug
  void logConnectionHistory() {
    debugPrint('📡 [PUSHER CONNECTION HISTORY]');
    debugPrint('   Initialized: $_isInitialized');
    debugPrint('   Current State: $_connectionState');
    debugPrint('   Is Connecting: $_isConnecting');
    debugPrint('   Active Channels: ${_activeChannels.length}');
    debugPrint('   Desired Channels: ${_desiredChannels.length}');
  }

  /// Unsubscribe from all channels
  Future<void> unsubscribeAll() async {
    final channels = _activeChannels.toList();
    for (final channel in channels) {
      await unsubscribe(channel);
    }
  }

  /// Debug subscriptions - ADDED FOR COMPATIBILITY
  void debugSubscriptions() {
    debugPrint('🔍 PusherService Debug:');
    debugPrint('   Initialized: $_isInitialized');
    debugPrint('   Connected: ${isConnected}');
    debugPrint('   Connection State: $_connectionState');
    debugPrint('   Desired Channels: ${_desiredChannels.toList()}');
    debugPrint('   Active Channels: ${_activeChannels.toList()}');
    debugPrint('   Event Handlers:');
    _handlers.forEach((channel, handlers) {
      debugPrint('     - $channel: ${handlers.length} handlers');
    });
  }

  // ========== PRIVATE METHODS ==========

  /// Add a connection state listener
  void addConnectionListener(ValueChanged<ConnectionState> listener) {
    if (!_connectionListeners.contains(listener)) {
      _connectionListeners.add(listener);
    }
  }

  ValueNotifier<ConnectionState> get connectionNotifier {
    return ValueNotifier<ConnectionState>(_connectionState);
  }

  // Add this method to PusherService class
  void debugConnection() {
    debugPrint('=== PUSHER DEBUG ===');
    debugPrint('Initialized: $_isInitialized');
    debugPrint('Connected: $isConnected');
    debugPrint('Connection State: $_connectionState');
    debugPrint('Connecting: $_isConnecting');
    debugPrint('Desired Channels: ${_desiredChannels.toList()}');
    debugPrint('Active Channels: ${_activeChannels.toList()}');
    debugPrint('Handlers per channel:');
    _handlers.forEach((channel, handlers) {
      debugPrint('  $channel: ${handlers.length} handlers');
    });
    debugPrint('=== END DEBUG ===');
  }

  /// Remove a connection state listener
  void removeConnectionListener(ValueChanged<ConnectionState> listener) {
    _connectionListeners.remove(listener);
  }

  dynamic _handleAuthorizer(
    String channelName,
    String socketId,
    dynamic options,
  ) {
    if (_authCallback == null) {
      throw Exception('No auth callback provided for private channel');
    }

    final optionsMap = options is Map<String, dynamic>
        ? options
        : <String, dynamic>{};

    return _authCallback!(channelName, socketId, optionsMap);
  }

  void _updateConnectionState(ConnectionState state) {
    if (_connectionState == state) return;

    _connectionState = state;
    debugPrint('📡 Pusher Connection State: $state');

    for (final listener in _connectionListeners) {
      try {
        listener(state);
      } catch (e) {
        debugPrint('Error in connection state listener: $e');
      }
    }
  }

  void _onConnectionStateChange(dynamic currentState, dynamic previousState) {
    final state = (currentState ?? '').toString().toUpperCase();

    switch (state) {
      case 'CONNECTED':
        _isConnecting = false;
        _updateConnectionState(ConnectionState.connected);

        // Resubscribe to desired channels
        _resubscribeDesiredChannels();
        break;

      case 'DISCONNECTED':
        _isConnecting = false;
        _updateConnectionState(ConnectionState.disconnected);
        break;

      case 'FAILED':
        _isConnecting = false;
        _updateConnectionState(ConnectionState.failed);
        break;

      case 'CONNECTING':
        _updateConnectionState(ConnectionState.connecting);
        break;

      case 'RECONNECTING':
        _updateConnectionState(ConnectionState.reconnecting);
        break;
    }
  }

  Future<void> _resubscribeDesiredChannels() async {
    final channels = _desiredChannels.toList();

    for (final channel in channels) {
      if (!_activeChannels.contains(channel)) {
        try {
          await subscribe(channel);
        } catch (e) {
          debugPrint('❌ Failed to resubscribe to $channel: $e');
        }
      }
    }
  }

  // In your PusherService, add these methods:
  void debugPusherState() {
    debugPrint('🔍 [PusherService DEBUG]');
    debugPrint('  - isInitialized: $isInitialized');
    debugPrint('  - isConnected: $isConnected');
    debugPrint('  - connectionState: $connectionState');
    debugPrint('  - subscribedChannels: $subscribedChannels');
  }

  Future<void> testDirectConnection() async {
    debugPrint('🧪 Testing direct Pusher connection...');

    try {
      // Try a simple test without auth
      await connect();

      // Wait and check
      await Future.delayed(const Duration(seconds: 3));

      if (isConnected) {
        debugPrint('✅ Direct connection successful');
      } else {
        debugPrint('❌ Direct connection failed - state: $connectionState');
      }
    } catch (e, stack) {
      debugPrint('❌ Direct connection error: $e');
      debugPrint('Stack: $stack');
    }
  }

  void _onSubscriptionSucceeded(String channelName, dynamic data) {
    _activeChannels.add(channelName);
    debugPrint('✅ Subscribed to channel: $channelName');
  }

  void _onError(String message, int? code, dynamic e) {
    debugPrint('❌ Pusher error: $message (code: $code)');
  }

  void _onSubscriptionError(String message, dynamic e) {
    debugPrint('❌ Pusher subscription error: $message');
  }

  void _onDecryptionFailure(String event, String reason) {
    debugPrint('❌ Pusher decryption failure: $event, reason: $reason');
  }

  void _onMemberAdded(String channelName, PusherMember member) {
    debugPrint('👤 Member added to $channelName: ${member.userId}');
  }

  void _onMemberRemoved(String channelName, PusherMember member) {
    debugPrint('👤 Member removed from $channelName: ${member.userId}');
  }

  void _onEvent(PusherEvent event) {
    // ADD TIMESTAMP for tracking
    final timestamp = DateTime.now().toIso8601String();

    debugPrint('\n🎯 [EVENT ROUTING - $timestamp]');
    debugPrint('   Channel: ${event.channelName}');
    debugPrint('   Event: ${event.eventName}');
    debugPrint('   Raw data: ${event.data}');
    debugPrint('   Data type: ${event.data.runtimeType}');

    // DEBUG: Show ALL registered handlers BEFORE checking
    debugPrint(
      '🔍 [BEFORE CHECKING] Total channels with handlers: ${_handlers.length}',
    );

    _handlers.forEach((channel, eventMap) {
      debugPrint('   Channel: $channel');
      eventMap.forEach((eventName, handlers) {
        debugPrint('      Event: $eventName -> ${handlers.length} handlers');
      });
    });

    // Get the channel map
    final channelMap = _handlers[event.channelName];
    if (channelMap == null) {
      debugPrint('   ❌ No channel map found for ${event.channelName}');
      debugPrint('   Available channels: ${_handlers.keys.toList()}');
      return;
    }

    debugPrint('   ✅ Found channel map for ${event.channelName}');
    debugPrint('   Events registered in channel: ${channelMap.keys.toList()}');

    // Get handlers for THIS SPECIFIC EVENT
    final eventHandlers = channelMap[event.eventName];
    if (eventHandlers == null || eventHandlers.isEmpty) {
      debugPrint('   ❌ No handlers for event: ${event.eventName}');
      debugPrint('   Looking for exact match: "${event.eventName}"');

      // Check for case-insensitive match
      for (final registeredEvent in channelMap.keys) {
        if (registeredEvent.toLowerCase() == event.eventName.toLowerCase()) {
          debugPrint('   ⚠️ Found case-insensitive match: $registeredEvent');
        }
      }

      return;
    }

    debugPrint('   ✅ Found ${eventHandlers.length} handler(s) for this event');

    final payload = _parseEventData(event.data);
    debugPrint('   Parsed payload: $payload');
    debugPrint('   Payload type: ${payload.runtimeType}');

    // Only fire handlers for THIS event type
    for (int i = 0; i < eventHandlers.length; i++) {
      final handler = eventHandlers[i];
      try {
        debugPrint(
          '   🔧 Executing handler #${i + 1} (hash: ${handler.hashCode})',
        );
        handler(payload);
        debugPrint('   ✅ Handler #${i + 1} executed successfully');
      } catch (e, stack) {
        debugPrint('   ❌ Handler #${i + 1} error: $e');
        debugPrint(
          '   Stack: ${stack.toString().split('\n').take(3).join('\n        ')}',
        );
      }
    }

    debugPrint('🎯 [EVENT COMPLETE]\n');
  }

  Map<String, dynamic> _parseEventData(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final decoded = json.decode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  /// Cleanup resources
  /// Reset and dispose of current instance
  Future<void> dispose() async {
    try {
      await disconnect();
    } catch (e) {
      debugPrint('Error disposing Pusher: $e');
    } finally {
      _isInitialized = false;
      _isConnecting = false;
      _connectionState = ConnectionState.disconnected;
      _handlers.clear();
      _desiredChannels.clear();
      _activeChannels.clear();
      _connectionListeners.clear();
    }
  }

  /// Force reinitialize with new configuration
  Future<void> reinitialize({
    required String apiKey,
    required String cluster,
    String? authEndpoint,
    PusherAuthCallback? authCallback,
  }) async {
    debugPrint('🔄 Reinitializing Pusher with new configuration...');

    // Dispose current instance
    await dispose();

    // Reinitialize
    await initialize(
      apiKey: apiKey,
      cluster: cluster,
      authEndpoint: authEndpoint,
      authCallback: authCallback,
    );
  }

  // ========== GETTERS ==========

  bool get isConnected => _connectionState == ConnectionState.connected;
  bool get isInitialized => _isInitialized;
  ConnectionState get connectionState => _connectionState;
  List<String> get subscribedChannels => _activeChannels.toList();
}

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  disconnecting,
  failed,
}
