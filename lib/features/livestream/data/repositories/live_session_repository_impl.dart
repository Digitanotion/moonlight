// FILE: lib/features/livestream/data/repositories/live_session_repository_impl.dart
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show debugPrint;
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/livestream/data/models/live_session_models.dart';
import 'package:moonlight/features/livestream/data/models/premium_package_model.dart';
import 'package:moonlight/features/livestream/data/models/premium_status_model.dart';
import 'package:moonlight/features/livestream/data/models/wallet_model.dart';
import 'package:moonlight/features/livestream/domain/entities/live_end_analytics.dart';
import 'package:moonlight/features/livestream/domain/entities/live_join_request.dart';
import 'package:moonlight/features/livestream/domain/entities/live_entities.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_session_repository.dart';
import 'package:moonlight/features/livestream/domain/session/live_session_tracker.dart';

class LiveSessionRepositoryImpl implements LiveSessionRepository {
  final DioClient _client;
  final PusherService _pusher;
  final AgoraService _agora;
  final LiveSessionTracker _tracker;

  LiveSessionRepositoryImpl(
    this._client,
    this._pusher,
    this._agora,
    this._tracker,
  );

  // ===== STREAM CONTROLLERS WITH PROPER LIFECYCLE =====
  final _chatCtrl = StreamController<LiveChatMessage>.broadcast();
  final _viewersCtrl = StreamController<int>.broadcast();
  final _requestsCtrl = StreamController<LiveJoinRequest>.broadcast();
  final _pauseCtrl = StreamController<bool>.broadcast();
  final _giftsCtrl = StreamController<GiftEvent>.broadcast();
  final _endedCtrl = StreamController<bool>.broadcast();
  final _joinHandledCtrl = StreamController<JoinHandled>.broadcast();
  final _giftBroadcastCtrl = StreamController<HostGiftBroadcast>.broadcast();
  final _activeGuestCtrl = StreamController<String?>.broadcast();
  final _premiumCtrl = StreamController<PremiumStatusModel>.broadcast();

  // State flags
  bool _isDisposed = false;
  bool _isSessionActive = false;
  String? activeGuestUuid;
  bool _locallyPaused = false;
  final List<HostGiftBroadcast> _collectedGifts = [];

  bool _pusherEventsBound = false;
  bool _isStartingSession = false;
  Completer<void>? _pusherConnectionCompleter;

  // Viewer count management
  int? _lastViewerCount;
  Timer? _viewerDebounceTimer;
  final Map<String, List<PusherCallback>> _pusherBindings = {};
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 15);

  // Helper to safely add to stream controllers
  void _safeAddToStream<T>(StreamController<T> controller, T value) {
    if (!_isDisposed && !controller.isClosed) {
      // FIXED: Removed controller.hasListener check - still add even if no listeners
      controller.add(value);
    }
  }

  int get _id {
    final current = _tracker.current;
    if (current == null) {
      debugPrint('⚠️ No active livestream session in _id getter.');
      return -1; // Or throw a more specific error
    }
    return current.livestreamId;
  }

  @override
  Stream<LiveChatMessage> chatStream() => _chatCtrl.stream;
  @override
  Stream<int> viewersStream() => _viewersCtrl.stream;
  @override
  Stream<bool> pauseStream() => _pauseCtrl.stream;
  @override
  Stream<LiveJoinRequest> joinRequestStream() => _requestsCtrl.stream;
  @override
  Stream<GiftEvent> giftsStream() => _giftsCtrl.stream;
  @override
  Stream<bool> endedStream() => _endedCtrl.stream;
  @override
  Stream<JoinHandled> joinHandledStream() => _joinHandledCtrl.stream;
  @override
  Stream<String?> activeGuestUuidStream() => _activeGuestCtrl.stream;
  @override
  Stream<HostGiftBroadcast> watchGiftBroadcasts() => _giftBroadcastCtrl.stream;
  @override
  Stream<PremiumStatusModel> premiumStatusStream() => _premiumCtrl.stream;

  // Helper method for safe data parsing
  @override
  Map<String, dynamic> _asMap(dynamic data) {
    try {
      debugPrint('🔍 [_asMap] Raw data type: ${data.runtimeType}');

      // If already a Map<String, dynamic>
      if (data is Map<String, dynamic>) {
        debugPrint(
          '🔍 [_asMap] Already Map<String, dynamic>, keys: ${data.keys}',
        );
        return data;
      }

      // If Map<dynamic, dynamic> (from JSON)
      if (data is Map) {
        debugPrint('🔍 [_asMap] Casting Map to Map<String, dynamic>');
        return data.cast<String, dynamic>();
      }

      // If String, try to parse as JSON
      if (data is String) {
        debugPrint(
          '🔍 [_asMap] String data: ${data.length > 100 ? '${data.substring(0, 100)}...' : data}',
        );
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) {
            return decoded.cast<String, dynamic>();
          }
        } catch (e) {
          debugPrint('❌ [_asMap] JSON decode failed: $e');
        }
        return <String, dynamic>{};
      }

      // If it's a List or other type
      debugPrint('❌ [_asMap] Unsupported type: ${data.runtimeType}');
      return <String, dynamic>{};
    } catch (e) {
      debugPrint('❌ [_asMap] Critical error: $e');
      return <String, dynamic>{};
    }
  }

  @override
  void setLocalPause(bool paused) {
    _locallyPaused = paused;
    try {
      _agora.setMicEnabled(!paused);
      _agora.setCameraEnabled(!paused);
      debugPrint('🎯 Local pause set to: $paused');
    } catch (e) {
      debugPrint('❌ Failed to set Agora devices state: $e');
    }
  }

  @override
  Future<void> startSession({required String topic}) async {
    // Reset disposal flag when starting fresh
    _isDisposed = false;

    // Reset binding flags to ensure fresh setup
    _pusherEventsBound = false;
    _clearPusherBindings();
    await restartStreams();

    if (_isStartingSession) {
      debugPrint('⚠️ Live session already starting — skipping');
      return;
    }

    // Don't check _isSessionActive here - allow restarting
    _isStartingSession = true;

    final s = _tracker.current;
    if (s == null) {
      _isStartingSession = false;
      throw StateError('No active LiveStartPayload found.');
    }

    try {
      debugPrint('🚀 [LIVE SESSION] Starting...');

      // 1) Start Agora first
      debugPrint('🎥 Starting Agora...');
      await _agora.startPublishing(
        appId: s.appId,
        channel: s.channel,
        token: s.rtcToken,
        uidType: s.uidType,
        uid: s.uid,
      );
      debugPrint('✅ Agora started');

      // 2) Setup Pusher but don't block on it
      _setupPusherAsync(s.livestreamId);

      _isSessionActive = true;
      _isSessionActive = true;

      // 3) Start heartbeat
      _startHeartbeat();

      debugPrint('✅ Live session started');
    } catch (e, stack) {
      debugPrint('❌ Failed to start live session: $e\n$stack');
      _isStartingSession = false;
      rethrow;
    } finally {
      _isStartingSession = false;
    }
  }

  void _setupPusherAsync(int livestreamId) async {
    try {
      debugPrint('🔄 Setting up Pusher async...');

      // Wait a bit to ensure other initialization is done
      await Future.delayed(const Duration(seconds: 1));

      // Ensure Pusher is ready
      if (!_pusher.isInitialized) {
        debugPrint('⚠️ Pusher not initialized, skipping');
        return;
      }

      // Connect if not connected
      if (!_pusher.isConnected) {
        debugPrint('🔌 Connecting to Pusher...');
        await _pusher.connect().catchError((e) {
          debugPrint('⚠️ Pusher connection error: $e');
        });
      }

      // Wait for connection with timeout
      final connected = await _waitForPusherConnectionWithTimeout(
        timeout: const Duration(seconds: 5),
      );

      if (connected) {
        debugPrint('✅ Pusher connected');
        await _subscribeToPusherChannels(livestreamId);
        _setupPusherEventBindings(livestreamId);
      } else {
        debugPrint('⚠️ Pusher connection timeout, will retry later');
        // Schedule retry
        Future.delayed(const Duration(seconds: 5), () {
          _setupPusherAsync(livestreamId);
        });
      }
    } catch (e) {
      debugPrint('❌ Async Pusher setup error: $e');
    }
  }

  Future<void> _subscribeToPusherChannels(int livestreamId) async {
    final channels = [
      'live.$livestreamId.meta',
      'live.$livestreamId.chat',
      'live.$livestreamId.join',
      'live.$livestreamId',
      'live.$livestreamId.viewer',
      'live.$livestreamId.gifts',
    ];

    debugPrint(
      '📡 Starting channel subscriptions for livestream $livestreamId',
    );

    // Subscribe to all channels first
    for (final channel in channels) {
      try {
        debugPrint('🔄 Subscribing to channel: $channel');
        await _pusher.subscribe(channel);
        debugPrint('✅ Subscribed to $channel');

        // Add a small delay between subscriptions
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (e) {
        debugPrint('❌ Failed to subscribe to $channel: $e');
      }
    }

    debugPrint('📡 All channels subscribed');

    // REMOVE THIS LINE - bindings are already set up by _setupPusherAsync()
    // _setupPusherEventBindings(livestreamId);

    // Debug subscriptions
    _pusher.debugSubscriptions();
  }

  Future<bool> _waitForPusherConnectionWithTimeout({Duration? timeout}) async {
    timeout ??= const Duration(seconds: 5);

    final completer = Completer<bool>();
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    // Check current state
    if (_pusher.isConnected) {
      timer.cancel();
      return true;
    }

    // Listen for connection
    void connectionListener(ConnectionState state) {
      if (state == ConnectionState.connected && !completer.isCompleted) {
        timer.cancel();
        completer.complete(true);
      } else if (state == ConnectionState.failed && !completer.isCompleted) {
        timer.cancel();
        completer.complete(false);
      }
    }

    _pusher.addConnectionListener(connectionListener);

    try {
      return await completer.future;
    } finally {
      _pusher.removeConnectionListener(connectionListener);
    }
  }

  void _setupPusherEventBindings(int livestreamId) {
    // Always clear existing bindings first
    _clearPusherBindings();

    debugPrint(
      '🔧 Setting up Pusher event bindings for livestream $livestreamId',
    );

    if (_pusherEventsBound) {
      debugPrint('ℹ️ Pusher events already bound — skipping');
      return;
    }

    debugPrint(
      '🔧 Setting up Pusher event bindings for livestream $livestreamId',
    );

    final metaChannel = 'live.$livestreamId.meta';
    final viewerChannel = 'live.$livestreamId.viewer';
    final chatChannel = 'live.$livestreamId.chat';
    final rootChannel = 'live.$livestreamId';
    final joinChannel = 'live.$livestreamId.join';
    final giftsChannel = 'live.$livestreamId.gifts';

    // Viewer count updates
    _bindPusherEvent(viewerChannel, 'viewer.count', (data) {
      debugPrint('🎯 [VIEWER COUNT] Event received: $data');
      _handleViewerCount(data);
    });

    // Chat messages
    _bindPusherEvent(chatChannel, 'chat.message', (data) {
      debugPrint('🎯 [CHAT MESSAGE] Event received: $data');
      _handleChatMessage(data);
    });

    // Pause events
    _bindPusherEvent(metaChannel, 'live.paused', (data) {
      debugPrint('🎯 [PAUSE EVENT] Event received: $data');
      _handlePauseEvent(data);
    });

    // Participant events
    _bindPusherEvent(metaChannel, 'participant.added', (data) {
      debugPrint('🎯 [PARTICIPANT ADDED] Event received: $data');
      _handleParticipantAdded(data);
    });

    _bindPusherEvent(metaChannel, 'participant.removed', (data) {
      debugPrint('🎯 [PARTICIPANT REMOVED] Event received: $data');
      _handleParticipantRemoved(data);
    });

    _bindPusherEvent(metaChannel, 'participant.role_changed', (data) {
      debugPrint('🎯 [PARTICIPANT ROLE CHANGED] Event received: $data');
      _handleParticipantRoleChanged(data);
    });

    // Join requests
    _bindPusherEvent(joinChannel, 'join.created', (data) {
      debugPrint('🎯 [JOIN REQUEST] Event received: $data');
      _handleJoinRequest(data);
    });

    // Gift events
    _bindPusherEvent(giftsChannel, 'gift.sent', (data) {
      debugPrint('🎯 [GIFT EVENT] Event received: $data');
      _handleGiftEvent(data);
    });

    // Premium status
    _bindPusherEvent(rootChannel, 'premium_status_changed', (data) {
      debugPrint('🎯 [PREMIUM STATUS] Event received: $data');
      _handlePremiumStatus(data);
    });

    // Live ended
    _bindPusherEvent(rootChannel, 'live.ended', (data) {
      debugPrint('🎯 [LIVE ENDED] Event received: $data');
      _safeAddToStream(_endedCtrl, true);
    });

    // Debug bindings for troubleshooting
    _setupDebugBindings(livestreamId);

    _pusherEventsBound = true;
    debugPrint('✅ Pusher event bindings setup complete');
  }

  @override
  Future<void> restartStreams() async {
    // Reset state flags but don't setup bindings here
    _isDisposed = false;
    _pusherEventsBound = false;

    // Clear old bindings
    _clearPusherBindings();

    // Reset stream controller states but don't recreate them
    // (they should already exist from the initial creation)

    debugPrint('🔄 Streams restarted (state reset)');
  }

  void _setupDebugBindings(int livestreamId) {
    final channels = [
      'live.$livestreamId.meta',
      'live.$livestreamId.viewer',
      'live.$livestreamId.chat',
      'live.$livestreamId',
      'live.$livestreamId.join',
      'live.$livestreamId.gifts',
    ];

    for (final channel in channels) {
      _bindPusherEvent(channel, '*', (data) {
        debugPrint('🔍 [DEBUG $channel] Event data: ${data.runtimeType}');
        if (data is Map) {
          debugPrint('🔍 [DEBUG $channel] Keys: ${data.keys}');
        }
      });
    }
  }

  void _bindPusherEvent(
    String channel,
    String event,
    PusherCallback handler, // FIXED: Use PusherCallback type
  ) {
    try {
      _pusher.bind(channel, event, handler);

      // Track the binding for cleanup
      final key = '$channel:$event';
      if (!_pusherBindings.containsKey(key)) {
        _pusherBindings[key] = [];
      }
      _pusherBindings[key]!.add(handler);

      debugPrint('🔗 Bound $event on $channel');
    } catch (e) {
      debugPrint('❌ Failed to bind $event on $channel: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => _sendHeartbeat(),
    );
    debugPrint('💓 Heartbeat started');
  }

  Future<void> _sendHeartbeat() async {
    // if (!_isSessionActive || _isDisposed) return;

    final current = _tracker.current;
    if (current == null) return;

    try {
      await _client.dio.post('/api/v1/live/${current.livestreamId}/heartbeat');
      debugPrint('💓 Heartbeat sent');
    } catch (e) {
      debugPrint('⚠️ Heartbeat failed (will retry): $e');
    }
  }

  // Add this test method for debugging
  void testPusherConnection() {
    debugPrint('🧪 Testing Pusher Connection...');
    debugPrint('  Initialized: ${_pusher.isInitialized}');
    debugPrint('  Connected: ${_pusher.isConnected}');
    debugPrint('  Connection State: ${_pusher.connectionState}');
    debugPrint('  Subscribed Channels: ${_pusher.subscribedChannels}');

    // Test a simple event binding
    _pusher.bind('test-channel', 'test-event', (data) {
      debugPrint('📨 Test event received: $data');
    });

    debugPrint('✅ Test binding created');
  }

  @override
  Future<void> makeGuest(String userUuid) async {
    try {
      // Check if there's already an active guest
      if (activeGuestUuid != null) {
        debugPrint(
          '❌ Cannot make guest: Already have an active guest with UUID: $activeGuestUuid',
        );
        throw Exception(
          'Already have an active guest. Remove current guest first.',
        );
      }

      // Check if userUuid is valid
      if (userUuid.isEmpty) {
        throw Exception('Invalid user UUID');
      }

      // Make API call to make this user a guest
      await _client.dio.post(
        '/api/v1/live/$_id/participants/$userUuid/make-guest',
      );

      debugPrint('✅ Made user $userUuid a guest');

      // Note: The actual guest assignment will come via Pusher event
      // (participant.role_changed or participant.added)
    } catch (e) {
      debugPrint('❌ Error making guest: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeGuest() async {
    try {
      if (activeGuestUuid == null) {
        debugPrint('⚠️ No active guest to remove');
        return;
      }

      await _client.dio.delete(
        '/api/v1/live/$_id/participants/$activeGuestUuid/remove-guest',
      );

      debugPrint('✅ Removed guest $activeGuestUuid');

      // Clear local state immediately
      activeGuestUuid = null;
      _safeAddToStream(_activeGuestCtrl, null);
      _agora.clearGuest();
    } catch (e) {
      debugPrint('❌ Error removing guest: $e');
      rethrow;
    }
  }

  @override
  Future<void> kickGuest() async {
    try {
      if (activeGuestUuid == null) {
        debugPrint('⚠️ No active guest to kick');
        return;
      }

      await _client.dio.post(
        '/api/v1/live/$_id/participants/$activeGuestUuid/kick',
      );

      debugPrint('✅ Kicked guest $activeGuestUuid');

      // Clear local state immediately
      activeGuestUuid = null;
      _safeAddToStream(_activeGuestCtrl, null);
      _agora.clearGuest();
    } catch (e) {
      debugPrint('❌ Error kicking guest: $e');
      rethrow;
    }
  }

  // ===== EVENT HANDLERS =====

  void _handleViewerCount(Map<String, dynamic> raw) {
    try {
      if (raw.isEmpty) return;

      final count = raw['count'];
      if (count == null) return;

      final viewerCount = count is num
          ? count.toInt()
          : int.tryParse('$count') ?? 0;

      // Cancel existing debounce timer
      _viewerDebounceTimer?.cancel();

      // Debounce updates to prevent UI flickering
      _viewerDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!_isDisposed) {
          debugPrint('🎯 [VIEWER] Update: $viewerCount');
          _safeAddToStream(_viewersCtrl, viewerCount);
        }
      });
    } catch (e) {
      debugPrint('❌ [VIEWER HANDLER] Error: $e');
    }
  }

  void _handleChatMessage(Map<String, dynamic> raw) {
    try {
      if (raw.isEmpty) return;

      debugPrint('🔍 [CHAT] Raw data: $raw');

      // Handle different event structures
      Map<String, dynamic> chatData;
      if (raw.containsKey('chat') && raw['chat'] is Map) {
        chatData = _asMap(raw['chat']);
      } else if (raw.containsKey('data') && raw['data'] is Map) {
        chatData = _asMap(raw['data']);
      } else {
        chatData = raw;
      }

      final text = (chatData['text'] ?? '').toString().trim();
      if (text.isEmpty) return;

      final role = (chatData['role'] ?? 'viewer').toString();
      final avatarUrl = (chatData['role'] ?? 'viewer').toString();
      // Extract user handle
      String handle = 'user';
      final userData = chatData['user'];
      if (userData is Map) {
        final userMap = _asMap(userData);
        handle =
            '${userMap['user_slug'] ?? userMap['slug'] ?? userMap['display_name'] ?? 'user'}';
      } else if (userData != null) {
        handle = '$userData';
      }

      debugPrint('🎯 [CHAT] Sending: $handle: $text');
      _safeAddToStream(
        _chatCtrl,
        LiveChatMessage(handle, text, role, avatarUrl),
      );
    } catch (e) {
      debugPrint('❌ [CHAT HANDLER] Error: $e\n${StackTrace.current}');
    }
  }

  void _handlePauseEvent(Map<String, dynamic> raw) {
    try {
      if (raw.isEmpty) return;

      final paused =
          raw['paused'] == true ||
          raw['paused'] == 'true' ||
          raw['paused'] == 1;

      debugPrint('🎯 [PAUSE] Setting to: $paused');
      _safeAddToStream(_pauseCtrl, paused);
      setLocalPause(paused);
    } catch (e) {
      debugPrint('❌ [PAUSE HANDLER] Error: $e');
    }
  }

  void _handleParticipantAdded(Map<String, dynamic> raw) {
    try {
      final uuid = (raw['user_uuid'] ?? raw['uuid'] ?? '').toString();
      final role = (raw['role'] ?? 'viewer').toString().toLowerCase();
      final agoraUid = (raw['agora_uid'] ?? raw['uid'])?.toString();

      debugPrint('👤 [PARTICIPANT ADDED] UUID: $uuid, Role: $role');

      if ((role == 'guest' || role == 'cohost')) {
        // ENFORCE SINGLE GUEST RULE
        if (activeGuestUuid != null && activeGuestUuid != uuid) {
          debugPrint(
            '⚠️ [SECURITY] Attempted to add second guest while one is already active. Rejecting.',
          );
          // Optionally, you could make an API call to revert this
          return;
        }

        activeGuestUuid = uuid;
        _safeAddToStream(_activeGuestCtrl, uuid);

        if (agoraUid != null && agoraUid.isNotEmpty) {
          final uid = int.tryParse(agoraUid);
          if (uid != null) {
            Future.delayed(const Duration(milliseconds: 1000), () {
              _agora.setPrimaryGuest(uid);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [PARTICIPANT ADDED HANDLER] Error: $e');
    }
  }

  void _handleParticipantRemoved(Map<String, dynamic> raw) {
    try {
      final uuid = (raw['user_uuid'] ?? raw['uuid'] ?? '').toString();

      if (uuid.isNotEmpty && uuid == activeGuestUuid) {
        activeGuestUuid = null;
        _safeAddToStream(_activeGuestCtrl, null);
        _agora.clearGuest();
        debugPrint('🎯 Active guest cleared due to removal.');
      }
    } catch (e) {
      debugPrint('❌ [PARTICIPANT REMOVED HANDLER] Error: $e');
    }
  }

  void _handleParticipantRoleChanged(Map<String, dynamic> raw) {
    try {
      final uuid = (raw['user_uuid'] ?? raw['uuid'] ?? '').toString();
      final role = (raw['role'] ?? '').toString().toLowerCase();
      final agoraUid = (raw['agora_uid'] ?? raw['uid'])?.toString();

      if (uuid.isEmpty || role.isEmpty) return;

      if (role == 'guest' || role == 'cohost') {
        // ENFORCE SINGLE GUEST RULE
        if (activeGuestUuid != null && activeGuestUuid != uuid) {
          debugPrint(
            '⚠️ [SECURITY] Attempted to promote second guest while one is already active. Rejecting.',
          );
          // Optionally, you could make an API call to revert this
          return;
        }

        if (activeGuestUuid != uuid) {
          activeGuestUuid = uuid;
          _safeAddToStream(_activeGuestCtrl, uuid);

          if (agoraUid != null && agoraUid.isNotEmpty) {
            final uid = int.tryParse(agoraUid);
            if (uid != null) {
              Future.delayed(const Duration(milliseconds: 500), () {
                _agora.setPrimaryGuest(uid);
              });
            }
          }
        }
      } else {
        if (uuid == activeGuestUuid) {
          activeGuestUuid = null;
          _safeAddToStream(_activeGuestCtrl, null);
          _agora.clearGuest();
        }
      }
    } catch (e) {
      debugPrint('❌ [PARTICIPANT ROLE HANDLER] Error: $e');
    }
  }

  void _handleJoinRequest(Map<String, dynamic> raw) {
    try {
      final id = (raw['id'] ?? raw['request_id'] ?? '').toString();
      final user = (raw['user'] as Map?)?.cast<String, dynamic>() ?? const {};
      final slug = (user['user_slug'] ?? user['slug'] ?? 'guest').toString();
      final avatar = (user['avatar'] ?? '').toString();
      final display = (user['display_name'] ?? slug).toString();

      if (id.isEmpty) return;

      debugPrint('🎯 Join request from: $display');
      _safeAddToStream(
        _requestsCtrl,
        LiveJoinRequest(
          id: id,
          displayName: display,
          role: 'Viewer',
          avatarUrl: avatar,
          online: true,
        ),
      );
    } catch (e) {
      debugPrint('❌ [JOIN REQUEST HANDLER] Error: $e');
    }
  }

  void _handleGiftEvent(Map<String, dynamic> raw) {
    try {
      debugPrint('🔍 [GIFT EVENT] Raw data: $raw');

      // Extract sender information
      String from = 'Someone';
      if (raw['sender'] is Map) {
        final senderMap = (raw['sender'] as Map).cast<String, dynamic>();
        from = (senderMap['display_name'] ?? 'Someone').toString();
      }

      // Extract gift information - note: the JSON has "gift_code" not "gift"
      final giftCode = (raw['gift_code'] ?? raw['gift'] ?? 'Gift').toString();
      final giftName = giftCode; // You might want to map this to a display name

      // Use coins_spent instead of coins
      final coins = raw['coins_spent'] is int
          ? raw['coins_spent'] as int
          : int.tryParse('${raw['coins_spent']}') ?? 0;

      debugPrint('🎁 Gift from $from: $giftCode ($coins coins)');

      _safeAddToStream(
        _giftsCtrl,
        GiftEvent(
          id:
              raw['server_txn_id'] ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          from: from,
          giftName: giftName,
          coins: coins,
        ),
      );

      // Also handle host gift broadcast
      _handleHostGiftBroadcast(raw);
    } catch (e) {
      debugPrint('❌ [GIFT HANDLER] Error: $e\n${StackTrace.current}');
    }
  }

  void _handleHostGiftBroadcast(Map<String, dynamic> raw) {
    try {
      final serverTxnId = (raw['server_txn_id'] ?? '').toString();
      final giftId = (raw['gift_id'] ?? '').toString();
      final giftCode = (raw['gift_code'] ?? raw['gift'] ?? '').toString();
      final quantity = raw['quantity'] is int
          ? raw['quantity'] as int
          : int.tryParse('${raw['quantity']}') ?? 1;
      final coinsSpent = raw['coins_spent'] is int
          ? raw['coins_spent'] as int
          : int.tryParse('${raw['coins_spent'] ?? raw['coins']}') ?? 0;

      String senderUuid = '';
      String senderDisplayName = (raw['from'] ?? 'Someone').toString();
      String? senderAvatar;

      if (raw['sender'] is Map) {
        final s = (raw['sender'] as Map).cast<String, dynamic>();
        senderUuid = (s['user_uuid'] ?? s['uuid'] ?? '').toString();
        senderDisplayName =
            (s['display_name'] ?? s['name'] ?? senderDisplayName).toString();
        senderAvatar = (s['avatar'] ?? s['avatar_url'] ?? '').toString();
        if (senderAvatar.isEmpty) senderAvatar = null;
      }

      final hb = HostGiftBroadcast(
        serverTxnId: serverTxnId.isEmpty
            ? DateTime.now().millisecondsSinceEpoch.toString()
            : serverTxnId,
        giftId: giftId.isEmpty
            ? DateTime.now().millisecondsSinceEpoch.toString()
            : giftId,
        giftCode: giftCode,
        giftName: (raw['gift_name'] ?? raw['gift'] ?? '').toString(),
        quantity: quantity,
        coinsSpent: coinsSpent,
        senderUuid: senderUuid,
        senderDisplayName: senderDisplayName,
        senderAvatar: senderAvatar,
        timestamp: DateTime.now().toUtc(),
        comboIndex: 0,
        comboWindowMs: 2000,
      );

      _safeAddToStream(_giftBroadcastCtrl, hb);
      _collectedGifts.add(hb);
    } catch (e) {
      debugPrint('❌ [HOST GIFT BROADCAST] Parse failed: $e');
    }
  }

  void _handlePremiumStatus(Map<String, dynamic> raw) {
    try {
      debugPrint('🔍 [PREMIUM] Raw event: $raw');

      // Extract premium data
      Map<String, dynamic> premiumMap = raw;
      if (raw.containsKey('premium') && raw['premium'] is Map) {
        premiumMap = _asMap(raw['premium']);
      } else if (raw.containsKey('data') && raw['data'] is Map) {
        final dataMap = _asMap(raw['data']);
        if (dataMap.containsKey('premium') && dataMap['premium'] is Map) {
          premiumMap = _asMap(dataMap['premium']);
        }
      }

      final isPremium =
          premiumMap['is_premium'] == true ||
          premiumMap['premium'] == true ||
          premiumMap['type'] == 'premium';

      final livestreamId = premiumMap['livestream_id'] is int
          ? premiumMap['livestream_id'] as int
          : int.tryParse('${premiumMap['livestream_id'] ?? '0'}') ?? 0;

      final package = premiumMap['package'] is Map
          ? _asMap(premiumMap['package'])
          : <String, dynamic>{};

      final model = PremiumStatusModel(
        type: premiumMap['type']?.toString() ?? 'premium_status_changed',
        livestreamId: livestreamId,
        isPremium: isPremium,
        package: PremiumPackageSummary(
          id: package['id']?.toString() ?? '',
          name: package['name']?.toString() ?? '',
          coins: package['coins'] is int ? package['coins'] as int : 0,
        ),
      );

      debugPrint('✅ [PREMIUM] Status: isPremium=$isPremium');
      _safeAddToStream(_premiumCtrl, model);
    } catch (e) {
      debugPrint('❌ [PREMIUM HANDLER] Error: $e\n${StackTrace.current}');
    }
  }

  // ===== CLEANUP METHODS =====

  void _clearPusherBindings() {
    for (final entry in _pusherBindings.entries) {
      final parts = entry.key.split(':');
      if (parts.length == 2) {
        final channel = parts[0];
        final event = parts[1];
        for (final handler in entry.value) {
          try {
            _pusher.unbind(channel, event, handler);
          } catch (e) {
            debugPrint('❌ Failed to unbind $event on $channel: $e');
          }
        }
      }
    }
    _pusherBindings.clear();
    _pusherEventsBound = false;
    debugPrint('🧹 Cleared all Pusher bindings');
  }

  Future<void> _cleanupPusherSubscriptions() async {
    try {
      // Unsubscribe from all live.* channels
      final subscribedChannels = _pusher.subscribedChannels;
      for (final channel in subscribedChannels) {
        if (channel.startsWith('live.')) {
          await _pusher.unsubscribe(channel);
        }
      }
      _clearPusherBindings();
      debugPrint('✅ Cleaned up Pusher subscriptions');
    } catch (e) {
      debugPrint('⚠️ Error cleaning up Pusher subscriptions: $e');
    }
  }

  Future<void> _cleanupSessionResources() async {
    try {
      debugPrint('🧹 Cleaning up session resources...');

      // Set local pause first
      try {
        setLocalPause(true);
      } catch (e) {
        debugPrint('⚠️ Error setting local pause: $e');
      }

      // Cancel timers
      _viewerDebounceTimer?.cancel();
      _viewerDebounceTimer = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      // Cleanup Pusher
      try {
        await _cleanupPusherSubscriptions();
      } catch (e) {
        debugPrint('⚠️ Error cleaning up Pusher: $e');
      }

      // Cleanup Agora
      try {
        await _agora.leave();
      } catch (e) {
        debugPrint('⚠️ Error leaving Agora: $e');
      }

      // try {
      //   await _agora.disposeEngine();
      // } catch (e) {
      //   debugPrint('⚠️ Error disposing Agora engine: $e');
      // }

      // Reset state
      try {
        _tracker.end();
      } catch (e) {
        debugPrint('⚠️ Error ending tracker: $e');
      }

      activeGuestUuid = null;
      _collectedGifts.clear();
      _lastViewerCount = null;
      _isSessionActive = false;
      _isStartingSession = false;

      debugPrint('✅ Session resources cleaned up');
    } catch (e) {
      debugPrint('❌ Critical error in cleanupSessionResources: $e');
    }
  }

  // For debugging
  Future<void> safeEndSession() async {
    try {
      if (!_isSessionActive) {
        debugPrint('ℹ️ No active session to end');
        return;
      }

      debugPrint('🔍 SAFE END - Current state:');
      debugPrint('  _isDisposed: $_isDisposed');
      debugPrint('  _isSessionActive: $_isSessionActive');
      debugPrint('  _tracker.current: ${_tracker.current}');
      debugPrint('  _pusher.isConnected: ${_pusher.isConnected}');

      await endSession();
    } catch (e, stack) {
      debugPrint('❌ SAFE END failed: $e');
      debugPrint('Stack: $stack');
    }
  }

  // ===== PUBLIC API METHODS =====

  @override
  Future<List<PremiumPackageModel>> fetchCoinPackages() async {
    try {
      final res = await _client.dio.get('/api/v1/wallet/packages');
      final map = (res.data as Map).cast<String, dynamic>();
      final list = (map['data'] as List?) ?? [];
      return List<PremiumPackageModel>.from(
        list.map(
          (e) =>
              PremiumPackageModel.fromMap((e as Map).cast<String, dynamic>()),
        ),
      );
    } catch (e) {
      debugPrint('❌ fetchCoinPackages error: $e');
      rethrow;
    }
  }

  @override
  Future<WalletModel> fetchWallet() async {
    try {
      final res = await _client.dio.get('/api/v1/wallet/');
      final map = (res.data as Map).cast<String, dynamic>();
      final data = (map['data'] as Map?)?.cast<String, dynamic>() ?? {};
      return WalletModel.fromMap(data);
    } catch (e) {
      debugPrint('❌ fetchWallet error: $e');
      rethrow;
    }
  }

  @override
  Future<PremiumStatusModel> activatePremium({
    required int livestreamId,
    required String packageId,
    required String packageName,
    required String coins,
    String? idempotencyKey,
  }) async {
    try {
      final opts = idempotencyKey == null
          ? null
          : Options(headers: {'Idempotency-Key': idempotencyKey});
      final res = await _client.dio.post(
        '/api/v1/live/$livestreamId/premium/activate',
        data: {
          "package": {"id": packageId, "name": packageName, "coins": coins},
        },
        // options: opts,
      );

      final map = (res.data is Map)
          ? (res.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      final premiumMap = (((map['data'] ?? {}) as Map?)?['premium']) as Map?;
      if (premiumMap != null) {
        final model = PremiumStatusModel.fromMap(
          premiumMap.cast<String, dynamic>(),
        );
        _safeAddToStream(_premiumCtrl, model);
        return model;
      }

      final status = (map['status'] ?? '').toString().toLowerCase();
      final message = (map['message'] ?? '').toString().toLowerCase();
      final isProcessing = status == 'error' && message.contains('processing');
      final is202 = res.statusCode == 202;

      if (isProcessing || is202) {
        final pending = PremiumStatusModel(
          type: 'pending',
          livestreamId: livestreamId,
          isPremium: true,
          package: PremiumPackageSummary(id: packageId, name: '', coins: 0),
        );
        _safeAddToStream(_premiumCtrl, pending);
        return pending;
      }

      throw Exception('Invalid server response: missing premium');
    } catch (e) {
      debugPrint('❌ activatePremium error: $e');
      rethrow;
    }
  }

  @override
  Future<PremiumStatusModel> cancelPremium({
    required int livestreamId,
    String? idempotencyKey,
  }) async {
    try {
      final opts = idempotencyKey == null
          ? null
          : Options(headers: {'Idempotency-Key': idempotencyKey});
      final res = await _client.dio.post(
        '/api/v1/live/$livestreamId/premium/cancel',
        data: {'reason': 'host_cancelled'},
        options: opts,
      );
      final map = (res.data as Map).cast<String, dynamic>();
      final premiumMap = ((map['data'] ?? {}) as Map)['premium'] as Map?;
      if (premiumMap == null) {
        throw Exception('Invalid server response: missing premium');
      }
      final model = PremiumStatusModel.fromMap(
        premiumMap.cast<String, dynamic>(),
      );
      _safeAddToStream(_premiumCtrl, model);
      return model;
    } catch (e) {
      debugPrint('❌ cancelPremium error: $e');
      rethrow;
    }
  }

  @override
  Future<void> endSession() async {
    if (!_isSessionActive) {
      debugPrint('⚠️ No active session to end');
      return;
    }

    _isSessionActive = false;

    try {
      await endAndFetchAnalytics();
      debugPrint('✅ Live session ended successfully');
    } catch (e) {
      debugPrint(
        '⚠️ Error ending session on server (may already be ended): $e',
      );
    }

    await _cleanupSessionResources();
  }

  @override
  Future<LiveEndAnalytics> endAndFetchAnalytics() async {
    // Cancel heartbeat first
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    final current = _tracker.current;
    if (current == null) {
      debugPrint('⚠️ No active livestream session in tracker.');
      // Return default analytics instead of throwing
      return LiveEndAnalytics(
        status: 'ended',
        endedAtIso: DateTime.now().toUtc().toIso8601String(),
        durationFormatted: '00:00:00',
        durationSeconds: 0.0,
        totalViewers: 0,
        totalChats: 0,
        coinsAmount: 0,
        coinsCurrency: 'coins',
      );
    }

    try {
      final res = await _client.dio.post(
        '/api/v1/live/${current.livestreamId}/end',
      );
      final data = (res.data as Map).cast<String, dynamic>();

      final analytics =
          (data['analytics'] as Map?)?.cast<String, dynamic>() ?? {};
      final dur =
          (analytics['stream_duration'] as Map?)?.cast<String, dynamic>() ?? {};
      final coins =
          (analytics['coins_earned'] as Map?)?.cast<String, dynamic>() ?? {};

      return LiveEndAnalytics(
        status: (data['status'] ?? '').toString(),
        endedAtIso: data['ended_at'] as String?,
        durationFormatted: (dur['formatted'] ?? '00:00:00').toString(),
        durationSeconds: double.tryParse('${dur['seconds'] ?? 0}') ?? 0.0,
        totalViewers: int.tryParse('${analytics['total_viewers'] ?? 0}') ?? 0,
        totalChats: int.tryParse('${analytics['total_chats'] ?? 0}') ?? 0,
        coinsAmount: int.tryParse('${coins['amount'] ?? 0}') ?? 0,
        coinsCurrency: (coins['currency'] ?? 'coins').toString(),
      );
    } catch (e) {
      debugPrint('❌ Error in endAndFetchAnalytics: $e');
      // Return default analytics on error
      return LiveEndAnalytics(
        status: 'error',
        endedAtIso: DateTime.now().toUtc().toIso8601String(),
        durationFormatted: '00:00:00',
        durationSeconds: 0.0,
        totalViewers: 0,
        totalChats: 0,
        coinsAmount: 0,
        coinsCurrency: 'coins',
      );
    } finally {
      // Clean up resources even if API call fails
      await _cleanupSessionResources();
    }
  }

  @override
  Future<void> acceptJoinRequest(String requestId) async {
    try {
      await _client.dio.post('/api/v1/live/$_id/join/$requestId/accept');
      debugPrint('✅ Join request accepted: $requestId');
    } catch (e) {
      debugPrint('❌ Error accepting join request: $e');
      rethrow;
    }
  }

  @override
  Future<void> declineJoinRequest(String requestId) async {
    try {
      await _client.dio.post('/api/v1/live/$_id/join/$requestId/decline');
      debugPrint('✅ Join request declined: $requestId');
    } catch (e) {
      debugPrint('❌ Error declining join request: $e');
      rethrow;
    }
  }

  @override
  Future<void> togglePause() async {
    try {
      final res = await _client.dio.post('/api/v1/live/$_id/pause');
      final data = (res.data is Map) ? res.data as Map : const {};
      final p = data['paused'];
      final paused = p == true || p == 'true' || p == 1;
      _safeAddToStream(_pauseCtrl, paused);
      setLocalPause(paused);
      debugPrint('✅ Live pause toggled to: $paused');
    } catch (e) {
      debugPrint('❌ Error toggling pause: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendChatMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return;

    try {
      await _client.dio.post(
        '/api/v1/live/$_id/chat',
        data: {'text': trimmedText},
      );
      debugPrint('✅ Chat message sent');
    } catch (e) {
      debugPrint('❌ Failed to send chat: $e');
      rethrow;
    }
  }

  @override
  Future<List<HostGiftBroadcast>> fetchCollectedGifts() async {
    return List<HostGiftBroadcast>.unmodifiable(_collectedGifts);
  }

  @override
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    debugPrint('🧹 Disposing LiveSessionRepository...');

    // Cancel timers
    _viewerDebounceTimer?.cancel();
    _viewerDebounceTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    // DON'T close stream controllers - just clear them
    // Keep controllers open for reuse
    try {
      // Clear any pending events
      if (_chatCtrl.hasListener) {
        _chatCtrl.add(LiveChatMessage('', '', '', ''));
      }
      // Repeat for other controllers...
    } catch (e) {
      debugPrint('⚠️ Error clearing stream controllers: $e');
    }

    // Cleanup Pusher
    try {
      _cleanupPusherSubscriptions();
    } catch (e) {
      debugPrint('⚠️ Error cleaning up Pusher on dispose: $e');
    }

    // Reset state
    _collectedGifts.clear();
    activeGuestUuid = null;
    _lastViewerCount = null;

    debugPrint(
      '✅ LiveSessionRepository disposed (stream controllers kept open)',
    );
  }
}
