import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/livestream/data/models/live_session_models.dart';
import 'package:moonlight/features/livestream/data/models/premium_package_model.dart';
import 'package:moonlight/features/livestream/data/models/premium_status_model.dart';
import 'package:moonlight/features/livestream/data/models/wallet_model.dart';
// import 'package:moonlight/features/livestream/data/models/go_live_models.dart';
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
  final _giftBroadcastCtrl = StreamController<HostGiftBroadcast>.broadcast();
  final List<HostGiftBroadcast> _collectedGifts = [];
  // NEW: active guest UUID stream (null when no guest)
  final _activeGuestCtrl = StreamController<String?>.broadcast();
  final _premiumCtrl = StreamController<PremiumStatusModel>.broadcast();

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
  // Expose host-only gift broadcast stream (host listens and animates)
  Stream<HostGiftBroadcast> watchGiftBroadcasts() => _giftBroadcastCtrl.stream;

  @override
  void setLocalPause(bool paused) {
    _locallyPaused = paused;
    _agora.setMicEnabled(!paused);
    _agora.setCameraEnabled(!paused);
  }

  // Fetch coin packages
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

  // Fetch wallet
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

  // Activate Premium
  Future<PremiumStatusModel> activatePremium({
    required int livestreamId,
    required String packageId,
    String? idempotencyKey,
  }) async {
    try {
      final opts = idempotencyKey == null
          ? null
          : Options(headers: {'Idempotency-Key': idempotencyKey});
      final res = await _client.dio.post(
        '/api/v1/live/$livestreamId/premium/activate',
        data: {'package_id': packageId},
        options: opts,
      );

      // normalize response body
      final map = (res.data is Map)
          ? (res.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      // Try to find the "premium" object in data
      final premiumMap = (((map['data'] ?? {}) as Map?)?['premium']) as Map?;
      if (premiumMap != null) {
        final model = PremiumStatusModel.fromMap(
          premiumMap.cast<String, dynamic>(),
        );
        _premiumCtrl.add(model);
        return model;
      }

      // Handle "already processing" / 202 case: treat as pending
      final status = (map['status'] ?? '').toString().toLowerCase();
      final message = (map['message'] ?? '').toString().toLowerCase();
      final isProcessing = status == 'error' && message.contains('processing');
      final is202 = res.statusCode == 202;

      if (isProcessing || is202) {
        // Build a lightweight "pending" model so UI can show pending state.
        // package name/coins may be unknown here; create a minimal summary.
        final pending = PremiumStatusModel(
          type: 'pending',
          livestreamId: livestreamId,
          isPremium: true,
          package: PremiumPackageSummary(id: packageId, name: '', coins: 0),
        );
        _premiumCtrl.add(pending);
        return pending;
      }

      throw Exception('Invalid server response: missing premium');
    } catch (e) {
      debugPrint('❌ activatePremium error: $e');
      rethrow;
    }
  }

  // Cancel premium
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
      _premiumCtrl.add(model);
      return model;
    } catch (e) {
      debugPrint('❌ cancelPremium error: $e');
      rethrow;
    }
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

  // Expose premium stream
  Stream<PremiumStatusModel> premiumStatusStream() => _premiumCtrl.stream;

  // Add Pusher binding inside _setupPusherEventBindings (near other binds):

  // Bind premium_status_changed

  // Implement handler method in class:
  void _handlePremiumStatus(dynamic raw) {
    try {
      final m = _asMap(raw);
      // server may nest under "premium" or send directly. try both.
      final payload = (m['premium'] is Map) ? m['premium'] as Map : m;
      final pmap = (payload as Map).cast<String, dynamic>();
      final pm = PremiumStatusModel.fromMap(pmap);
      _premiumCtrl.add(pm);
      debugPrint('✅ Parsed premium status: isPremium=${pm.isPremium}');
    } catch (e) {
      debugPrint('❌ _handlePremiumStatus parse failed: $e');
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
    final giftsChannel = 'live.$livestreamId.gifts';

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
    _pusher.bind(giftsChannel, 'gift.sent', (raw) {
      print('🎯 Gift event received');
      _handleGiftEvent(raw);
    });

    try {
      _pusher.bind(rootChannel, 'premium_status_changed', (raw) {
        debugPrint('🎯 premium_status_changed received on root channel');
        _handlePremiumStatus(raw);
      });
      _pusher.bind(metaChannel, 'premium_status_changed', (raw) {
        debugPrint('🎯 premium_status_changed received on meta channel');
        _handlePremiumStatus(raw);
      });
    } catch (e) {
      debugPrint('⚠️ Failed to bind premium_status_changed: $e');
    }

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

    // Also attempt to parse and emit HostGiftBroadcast for host overlay subscription
    try {
      final serverTxnId = (m['server_txn_id'] ?? '').toString();
      final giftId = (m['gift_id'] ?? '').toString();
      final giftCode = (m['gift_code'] ?? gift).toString();
      final quantity = (m['quantity'] is int)
          ? m['quantity'] as int
          : int.tryParse('${m['quantity']}') ?? 1;
      final coinsSpent = (m['coins_spent'] is int)
          ? m['coins_spent'] as int
          : int.tryParse('${m['coins_spent'] ?? m['coins']}') ?? coins;

      String senderUuid = '';
      String senderDisplayName = from;
      String? senderAvatar;
      if (m['sender'] is Map) {
        final s = (m['sender'] as Map).cast<String, dynamic>();
        senderUuid = (s['user_uuid'] ?? s['uuid'] ?? '').toString();
        senderDisplayName = (s['display_name'] ?? s['name'] ?? from).toString();
        senderAvatar = (s['avatar'] ?? s['avatar_url'] ?? '').toString();
        if (senderAvatar.isEmpty) senderAvatar = null;
      }

      DateTime ts = DateTime.now().toUtc();
      try {
        if ((m['timestamp'] ?? '').toString().isNotEmpty) {
          ts = DateTime.parse(m['timestamp'].toString()).toUtc();
        }
      } catch (_) {}

      final combo = (m['combo'] is Map)
          ? (m['combo'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final comboIndex = combo['index'] is int
          ? combo['index'] as int
          : int.tryParse('${combo['index'] ?? ''}') ?? 0;
      final comboWindowMs = combo['window_ms'] is int
          ? combo['window_ms'] as int
          : int.tryParse('${combo['window_ms'] ?? ''}') ?? 2000;

      final hb = HostGiftBroadcast(
        serverTxnId: serverTxnId.isEmpty
            ? DateTime.now().millisecondsSinceEpoch.toString()
            : serverTxnId,
        giftId: giftId.isEmpty
            ? DateTime.now().millisecondsSinceEpoch.toString()
            : giftId,
        giftCode: giftCode,
        giftName: (m['gift_name'] ?? m['gift'] ?? '').toString(),
        quantity: quantity,
        coinsSpent: coinsSpent,
        senderUuid: senderUuid,
        senderDisplayName: senderDisplayName,
        senderAvatar: senderAvatar,
        timestamp: ts,
        comboIndex: comboIndex,
        comboWindowMs: comboWindowMs,
      );

      _giftBroadcastCtrl.add(hb);
      try {
        _collectedGifts.add(hb);
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ Host gift broadcast parse failed: $e');
    }
  }

  // Provide accumulated gifts for the current live session (host view)
  Future<List<HostGiftBroadcast>> fetchCollectedGifts() async {
    // return a copy to avoid external mutation
    return List<HostGiftBroadcast>.unmodifiable(_collectedGifts);
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
    _giftBroadcastCtrl.close();
    _collectedGifts.clear();
    _premiumCtrl.close();
    // Also drop any lingering channel bindings (safe even if none)
    // If you share PusherService elsewhere, this only affects the live.* channels we created.
    // We already call unsubscribeAll() at startSession; this is a “belt & suspenders” cleanup.
    try {
      _pusher.unsubscribeAll();
    } catch (_) {}
  }
}
