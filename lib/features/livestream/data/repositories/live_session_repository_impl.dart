import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
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

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      try {
        final m = jsonDecode(data);
        if (m is Map) return m.cast<String, dynamic>();
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  // Streams
  final _chatCtrl = StreamController<LiveChatMessage>.broadcast();
  final _viewersCtrl = StreamController<int>.broadcast();
  final _requestsCtrl = StreamController<LiveJoinRequest>.broadcast();
  final _pauseCtrl = StreamController<bool>.broadcast();
  final _giftsCtrl = StreamController<GiftEvent>.broadcast();
  final _endedCtrl = StreamController<void>.broadcast();
  final _joinHandledCtrl = StreamController<JoinHandled>.broadcast();
  // NEW: active guest UUID stream (null when no guest)
  final _activeGuestCtrl = StreamController<String?>.broadcast();
  String? _activeGuestUuid;

  bool _locallyPaused = false;
  int get _id => _tracker.current!.livestreamId;

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
  Stream<void> endedStream() => _endedCtrl.stream;
  @override
  Stream<JoinHandled> joinHandledStream() => _joinHandledCtrl.stream;
  Stream<String?> activeGuestUuidStream() => _activeGuestCtrl.stream;

  @override
  void setLocalPause(bool paused) {
    _locallyPaused = paused;
    _agora.setMicEnabled(!paused);
    _agora.setCameraEnabled(!paused);
  }

  @override
  Future<void> startSession({required String topic}) async {
    final s = _tracker.current;
    if (s == null) throw StateError('No active LiveStartPayload found.');

    try {
      // Clear any existing subscriptions for this livestream
      await _pusher.unsubscribePrefix('live.${s.livestreamId}');
    } catch (e) {
      debugPrint('Warning: Failed to unsubscribe from previous channels: $e');
    }

    // 1) Host goes live on Agora first
    try {
      await _agora.startPublishing(
        appId: s.appId,
        channel: s.channel,
        token: s.rtcToken,
        uidType: s.uidType,
        uid: s.uid,
      );
      debugPrint('✅ Agora publishing started');
    } catch (e) {
      debugPrint('❌ Agora publishing failed: $e');
      rethrow;
    }

    // 2) Connect to Pusher with retry logic
    await _connectPusherWithRetry();

    // 3) Subscribe to channels
    await _subscribeToPusherChannels(s.livestreamId);

    debugPrint('✅ Live session started successfully');
  }

  Future<void> _connectPusherWithRetry() async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _pusher.connect();
        debugPrint('✅ Pusher connected successfully');
        return;
      } catch (e) {
        debugPrint('❌ Pusher connection attempt $attempt failed: $e');
        if (attempt == maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  Future<void> _subscribeToPusherChannels(int livestreamId) async {
    final channels = [
      'live.$livestreamId.meta',
      'live.$livestreamId.chat',
      'live.$livestreamId.join',
      'live.$livestreamId',
      'live.$livestreamId.viewer',
    ];

    for (final channel in channels) {
      try {
        await _pusher.subscribe(channel);
        debugPrint('✅ Subscribed to $channel');

        // Add a small delay between subscriptions to avoid overwhelming Pusher
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('❌ Failed to subscribe to $channel: $e');
        // Continue with other channels even if one fails
      }
    }

    // Set up event bindings after all subscriptions are complete
    _setupPusherEventBindings(livestreamId);
    _pusher.debugSubscriptions();
  }

  void _setupPusherEventBindings(int livestreamId) {
    final metaChannel = 'live.$livestreamId.meta';
    final viewerChannel = 'live.$livestreamId.viewer';
    final chatChannel = 'live.$livestreamId.chat';
    final rootChannel = 'live.$livestreamId';
    final joinChannel = 'live.$livestreamId.join';

    debugPrint('🔧 Setting up event bindings for livestream $livestreamId');

    // Clear any existing bindings first (you'll need to add this method to PusherService)
    // _clearExistingBindings();

    // ========= VIEWER COUNT EVENTS =========
    // Bind to multiple channels/event names for reliability
    _pusher.bind(viewerChannel, 'viewer.count', (raw) {
      debugPrint('🎯 Viewer count event received on viewer channel');
      _handleViewerCount(raw, 'viewer');
    });

    _pusher.bind(metaChannel, 'viewer.count', (raw) {
      debugPrint('🎯 Viewer count event received on meta channel');
      _handleViewerCount(raw, 'meta');
    });

    _pusher.bind(rootChannel, 'viewer.count', (raw) {
      debugPrint('🎯 Viewer count event received on root channel');
      _handleViewerCount(raw, 'root');
    });

    // Also try the event name from your logs
    _pusher.bind(viewerChannel, 'viewer.count', (raw) {
      debugPrint('🎯 Viewer count event received (exact match)');
      _handleViewerCount(raw, 'viewer-exact');
    });

    // ========= PARTICIPANT EVENTS =========
    _pusher.bind(metaChannel, 'participant.added', (raw) {
      debugPrint('🎯 Participant added event received');
      _handleParticipantAdded(raw);
    });

    _pusher.bind(metaChannel, 'participant.removed', (raw) {
      debugPrint('🎯 Participant removed event received');
      _handleParticipantRemoved(raw);
    });

    _pusher.bind(metaChannel, 'participant.role_changed', (raw) {
      debugPrint('🎯 Participant role changed event received');
      _handleParticipantRoleChanged(raw);
    });

    // ========= CHAT MESSAGES =========
    _pusher.bind(chatChannel, 'chat.message', (raw) {
      debugPrint('🎯 Chat message event received');
      _handleChatMessage(raw);
    });

    // ========= PAUSE EVENTS =========
    _pusher.bind(metaChannel, 'live.paused', (raw) {
      debugPrint('🎯 Pause event received');
      _handlePauseEvent(raw);
    });

    // ========= LIVE ENDED =========
    _pusher.bind(rootChannel, 'live.ended', (raw) {
      debugPrint('🎯 Live ended event received');
      _endedCtrl.add(null);
    });

    // ========= JOIN REQUESTS =========
    _pusher.bind(joinChannel, 'join.created', (raw) {
      debugPrint('🎯 Join request event received');
      _handleJoinRequest(raw);
    });

    // ========= GIFT EVENTS =========
    _pusher.bind(rootChannel, 'gift.sent', (raw) {
      debugPrint('🎯 Gift event received');
      _handleGiftEvent(raw);
    });

    debugPrint('✅ All event bindings setup complete');
    debugPrint('   - Meta channel: $metaChannel');
    debugPrint('   - Viewer channel: $viewerChannel');
    debugPrint('   - Chat channel: $chatChannel');
    debugPrint('   - Root channel: $rootChannel');
    debugPrint('   - Join channel: $joinChannel');
  }

  // Enhance the participant added handler to log Agora UIDs
  void _handleParticipantAdded(Map<String, dynamic> raw) {
    debugPrint('👤 Participant added: $raw');
    final m = _asMap(raw);
    final uuid = (m['user_uuid'] ?? m['uuid'] ?? '').toString();
    final agoraUid = (m['agora_uid'] ?? m['uid'])?.toString();
    final role = (m['role'] ?? 'viewer').toString().toLowerCase();

    debugPrint(
      '🎯 Participant details - UUID: $uuid, Agora UID: $agoraUid, Role: $role',
    );

    // If this is a guest and we don't have an active guest, set them
    if ((role == 'guest' || role == 'cohost') && _activeGuestUuid == null) {
      _activeGuestUuid = uuid;
      _activeGuestCtrl.add(uuid);

      if (agoraUid != null && agoraUid.isNotEmpty) {
        final uid = int.tryParse(agoraUid);
        if (uid != null) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            _agora.setPrimaryGuest(uid);
          });
        }
      }
    }
  }

  void _handleParticipantRemoved(Map<String, dynamic> raw) {
    debugPrint('👤 Participant removed: $raw');
    final m = _asMap(raw);
    final uuid = (m['user_uuid'] ?? m['uuid'] ?? '').toString();

    if (uuid.isNotEmpty && uuid == _activeGuestUuid) {
      _activeGuestUuid = null;
      _activeGuestCtrl.add(null);
      _agora.clearGuest(); // ✅ also drop the pinned remote in the host engine
      debugPrint('🎯 Active guest cleared due to removal.');
    }
  }

  // Add this method to properly handle guest promotion/demotion
  void _handleParticipantRoleChanged(Map<String, dynamic> raw) {
    debugPrint('👤 Participant role changed: $raw');
    final m = _asMap(raw);
    final uuid = (m['user_uuid'] ?? m['uuid'] ?? '').toString();
    final role = (m['role'] ?? '').toString().toLowerCase();
    final agoraUid = (m['agora_uid'] ?? m['uid'])?.toString();

    if (uuid.isEmpty || role.isEmpty) return;

    if (role == 'guest' || role == 'cohost') {
      // Enforce single-guest: visually pin whoever just became guest.
      if (_activeGuestUuid != uuid) {
        _activeGuestUuid = uuid;
        _activeGuestCtrl.add(uuid);

        // If we have an Agora UID, set it as primary guest immediately
        if (agoraUid != null && agoraUid.isNotEmpty) {
          final uid = int.tryParse(agoraUid);
          if (uid != null) {
            // Small delay to ensure user has joined Agora channel
            Future.delayed(const Duration(milliseconds: 500), () {
              _agora.setPrimaryGuest(uid);
            });
          }
        }

        debugPrint(
          '🎯 Active guest now: $_activeGuestUuid (Agora UID: $agoraUid)',
        );
      }
    } else {
      // Demoted back to viewer/audience → clear if it was the active guest
      if (uuid == _activeGuestUuid) {
        _activeGuestUuid = null;
        _activeGuestCtrl.add(null);
        _agora.clearGuest();
        debugPrint('🎯 Active guest cleared (role -> $role).');
      }
    }
  }

  void _handleViewerCount(Map<String, dynamic> raw, String source) {
    final m = _asMap(raw);
    final rawCount = (m['count'] ?? m['viewers'] ?? 0);
    final count = rawCount is num
        ? rawCount.toInt()
        : int.tryParse('$rawCount') ?? 0;
    debugPrint('🎯 HOST ($source): Viewer count updated to $count');
    _viewersCtrl.add(count);
  }

  void _handleChatMessage(Map<String, dynamic> raw) {
    final m = _asMap(raw);
    final chatData = (m['chat'] is Map) ? _asMap(m['chat']) : m;

    final text = (chatData['text'] ?? '').toString();
    String handle = '@user';

    if (chatData['user'] is Map) {
      final user = _asMap(chatData['user']);
      handle = '@${user['user_slug'] ?? user['slug'] ?? 'user'}';
    } else {
      handle = '@${chatData['user'] ?? 'user'}';
    }

    debugPrint('🎯 Chat message: $handle: $text');
    _chatCtrl.add(LiveChatMessage(handle, text));
  }

  void _handlePauseEvent(Map<String, dynamic> raw) {
    final m = _asMap(raw);
    final p = m['paused'];
    final paused = p == true || p == 'true' || p == 1;
    debugPrint('🎯 Pause event: $paused');
    _pauseCtrl.add(paused);
    setLocalPause(paused);
  }

  void _handleJoinRequest(Map<String, dynamic> raw) {
    final m = _asMap(raw);
    final id = (m['id'] ?? m['request_id'] ?? '').toString();
    final user = (m['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final slug = (user['user_slug'] ?? user['slug'] ?? 'guest').toString();
    final avatar = (user['avatar'] ?? '').toString();
    final display = (user['display_name'] ?? slug).toString();

    if (id.isEmpty) return;

    debugPrint('🎯 Join request from: $display');
    _requestsCtrl.add(
      LiveJoinRequest(
        id: id,
        displayName: display,
        role: 'Viewer',
        avatarUrl: avatar,
        online: true,
      ),
    );
  }

  void _handleGiftEvent(Map<String, dynamic> raw) {
    final m = _asMap(raw);
    final from = (m['from'] ?? 'Someone').toString();
    final gift = (m['gift'] ?? 'Gift').toString();
    final coins = (m['coins'] is int)
        ? m['coins'] as int
        : int.tryParse('${m['coins']}') ?? 0;

    // debugPrint('🎯 Gift received: $gift from $display');
    _giftsCtrl.add(
      GiftEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        from: from,
        giftName: gift,
        coins: coins,
      ),
    );
  }

  @override
  Future<void> endSession() async {
    try {
      // baseUrl must be https://svc.moonlightstream.app/api/v1
      await _client.dio.post('/api/v1/live/$_id/end'); // relative path ✅
    } catch (_) {
      // idempotent; safe to ignore
    }
    setLocalPause(true);
    await _pusher.unsubscribeAll();
    await _agora.leave();
    await _agora.disposeEngine();
    _tracker.end();
  }

  @override
  Future<LiveEndAnalytics> endAndFetchAnalytics() async {
    final current = _tracker.current;
    if (current == null) {
      throw StateError('No active livestream session.');
    }
    // numeric id – your backend accepts numeric here
    final id = current.livestreamId;

    final res = await _client.dio.post('/api/v1/live/$_id/end');
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
  }

  @override
  Future<void> acceptJoinRequest(String requestId) async {
    await _client.dio.post(
      '/api/v1/live/$_id/join/$requestId/accept',
    ); // relative path ✅
  }

  @override
  Future<void> declineJoinRequest(String requestId) async {
    await _client.dio.post(
      '/api/v1/live/$_id/join/$requestId/decline',
    ); // relative path ✅
  }

  @override
  Future<void> togglePause() async {
    final res = await _client.dio.post(
      '/api/v1/live/$_id/pause',
    ); // relative path ✅
    final data = (res.data is Map) ? res.data as Map : const {};
    final p = data['paused'];
    final paused = p == true || p == 'true' || p == 1;
    _pauseCtrl.add(paused);
    setLocalPause(paused);
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
      // The message will appear via Pusher chat.message event
    } catch (e) {
      debugPrint('❌ Failed to send chat: $e');
      // You might want to show an error to the user
    }
  }

  @override
  void dispose() {
    _chatCtrl.close();
    _viewersCtrl.close();
    _requestsCtrl.close();
    _pauseCtrl.close();
    _giftsCtrl.close();
    _endedCtrl.close();
    _joinHandledCtrl.close();
    _activeGuestCtrl.close();
    // Also drop any lingering channel bindings (safe even if none)
    // If you share PusherService elsewhere, this only affects the live.* channels we created.
    // We already call unsubscribeAll() at startSession; this is a “belt & suspenders” cleanup.
    try {
      _pusher.unsubscribeAll();
    } catch (_) {}
  }
}
