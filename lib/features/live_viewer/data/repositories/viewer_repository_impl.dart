// lib/features/live_viewer/data/repositories/viewer_repository_impl.dart - CLEANED
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/domain/repositories/viewer_repository.dart';
import 'package:moonlight/features/live_viewer/domain/video_surface_provider.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';

/// Cleaned repository - data layer only, no UI rendering
///
///
typedef PusherCallback = void Function(Map<String, dynamic> payload);

class ViewerRepositoryImpl implements ViewerRepository {
  final DioClient http;
  final PusherService pusher;
  final AuthLocalDataSource authLocalDataSource;
  final AgoraViewerService agoraViewerService;
  final String livestreamParam;
  final int livestreamIdNumeric;
  final String channelName;
  final HostInfo? initialHost;
  final DateTime? startedAt;
  final String? hostUserUuid;
  final String? hostUserSlug;

  String? get hostUuid => hostUserUuid;
  String? get hostSlug => hostUserSlug;
  // Add this getter
  AgoraViewerService get agoraService => agoraViewerService;

  // State
  bool _hasStarted = false;
  bool _hasEnded = false;
  bool _isWiring = false;
  final Set<String> _boundEventKeys = <String>{};
  final List<String> _eventHistory = [];
  DateTime? _wireStartedAt;

  // Stream controllers
  final _clockCtrl = StreamController<Duration>.broadcast();
  final _viewerCtrl = StreamController<int>.broadcast();
  final _chatCtrl = StreamController<ChatMessage>.broadcast();
  final _guestCtrl = StreamController<GuestJoinNotice>.broadcast();
  final _giftCtrl = StreamController<GiftNotice>.broadcast();
  final _pauseCtrl = StreamController<bool>.broadcast();
  final _endedCtrl = StreamController<void>.broadcast();
  final _myApprovalCtrl = StreamController<bool>.broadcast();
  final _activeGuestCtrl = StreamController<String?>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();
  final _participantRoleCtrl = StreamController<String>.broadcast();
  final _participantRemovedCtrl = StreamController<String>.broadcast();
  final _giftBroadcastCtrl = StreamController<GiftBroadcast>.broadcast();

  // Gift catalog
  List<GiftItem> _giftCatalogCache = const [];
  String? _giftCatalogVersion;

  // Timing
  String? _activeGuestUuid;
  Timer? _clockTimer;
  Future<void>? _wiringFuture;
  bool _wired = false;
  String? _myJoinRequestId;
  bool _isRoleChangeInProgress = false;

  String get _basePath => '/api/v1/live/$livestreamParam';

  // In ViewerRepositoryImpl constructor, add:
  ViewerRepositoryImpl({
    required this.http,
    required this.pusher,
    required this.authLocalDataSource,
    required this.agoraViewerService,
    required this.livestreamParam,
    required this.livestreamIdNumeric,
    required this.channelName,
    this.hostUserUuid,
    this.hostUserSlug,
    this.initialHost,
    this.startedAt,
  }) {
    debugPrint(
      '🎯 [Repository] Created with AgoraViewerService: ${agoraViewerService != null}',
    );
    debugPrint(
      '🎯 [Repository] AgoraService hash: ${agoraViewerService.hashCode}',
    );
  }

  // ============ PUBLIC API - VIEWERREPOSITORY ============

  @override
  Future<HostInfo> fetchHostInfo() async {
    if (initialHost != null) return initialHost!;

    try {
      final res = await http.dio.get('${_basePath}/viewer/host-info');
      final data = _asMap(res.data);

      final hostData = data['host'] ?? data;
      return HostInfo(
        name:
            hostData['name']?.toString() ??
            hostData['user_slug']?.toString() ??
            'Host',
        title:
            hostData['title']?.toString() ??
            data['title']?.toString() ??
            'Live Stream',
        subtitle: hostData['subtitle']?.toString() ?? '',
        badge: hostData['badge']?.toString() ?? 'Superstar',
        avatarUrl:
            hostData['avatar']?.toString() ??
            hostData['avatar_url']?.toString() ??
            'https://via.placeholder.com/120x120.png?text=LIVE',
        isFollowed: hostData['is_followed'] == true,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to fetch host info: $e');
      return const HostInfo(
        name: 'Host',
        title: 'Live Stream',
        subtitle: '',
        badge: 'Superstar',
        avatarUrl: 'https://via.placeholder.com/120x120.png?text=LIVE',
        isFollowed: false,
      );
    }
  }

  @override
  Future<int?> fetchWalletBalance() async {
    try {
      final res = await http.dio.get('/api/v1/wallet');
      final m = _asMap(res.data);
      final data =
          (m['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final balance = data['balance'];
      if (balance is num) return balance.toInt();
      if (balance is String) return int.tryParse(balance);
      return null;
    } catch (e) {
      debugPrint('⚠️ fetchWalletBalance failed: $e');
      return null;
    }
  }

  @override
  Future<(List<GiftItem>, String?)> fetchGiftCatalog() async {
    try {
      final res = await http.dio.get('/api/v1/wallet/gifts');
      final data = _asMap(res.data);
      final List list = (data['data'] as List? ?? const []);
      final items = list
          .map((e) => GiftItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      _giftCatalogCache = items;
      _giftCatalogVersion = data['catalog_version']?.toString();
      return (items, _giftCatalogVersion);
    } catch (e) {
      debugPrint('⚠️ fetchGiftCatalog failed: $e');
      return (_giftCatalogCache, _giftCatalogVersion);
    }
  }

  @override
  Future<GiftSendResult> sendGift({
    required String giftCode,
    required String toUserUuid,
    required String livestreamId,
    int quantity = 1,
  }) async {
    try {
      final body = {
        'gift_code': giftCode,
        'to_user_uuid': toUserUuid,
        'livestream_id': livestreamId,
        'quantity': quantity,
        'idempotency_key': _genIdempotencyKey(),
      };
      final res = await http.dio.post('/api/v1/wallet/gift', data: body);
      final m = _asMap(res.data);
      final d = (m['data'] as Map).cast<String, dynamic>();
      final serverTxnId = '${d['server_txn_id']}';
      final newBal = (d['new_balance_coins'] as num).toInt();
      final b = GiftBroadcast.fromJson(
        (d['broadcast'] as Map).cast<String, dynamic>(),
      );
      return GiftSendResult(
        serverTxnId: serverTxnId,
        newBalanceCoins: newBal,
        broadcast: b,
      );
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e);
      _errorCtrl.add(msg);
      rethrow;
    }
  }

  @override
  Future<void> sendComment(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    try {
      await http.dio.post('$_basePath/chat', data: {'text': t});
    } catch (e) {
      debugPrint('⚠️ sendComment failed: $e');
      _errorCtrl.add('Failed to send comment: $e');
    }
  }

  @override
  Future<int> like() async {
    try {
      final res = await http.dio.post('$_basePath/like');
      final data = _asMap(res.data);
      return (data['likes'] ?? data['total_likes'] ?? 0) as int;
    } catch (e) {
      debugPrint('⚠️ like failed: $e');
      return 0;
    }
  }

  @override
  Future<int> share() async {
    try {
      final res = await http.dio.post('$_basePath/share');
      final data = _asMap(res.data);
      return (data['shares'] ?? data['total_shares'] ?? 0) as int;
    } catch (e) {
      debugPrint('⚠️ share failed: $e');
      return 0;
    }
  }

  @override
  Future<void> requestToJoin() async {
    try {
      final res = await http.dio.post('$_basePath/request-join');
      final data = _asMap(res.data);

      if (data['success'] == true) {
        _myJoinRequestId = data['request_id']?.toString();
        _myApprovalCtrl.add(true);
      }
    } catch (e) {
      debugPrint('⚠️ requestToJoin failed: $e');
      rethrow;
    }
  }

  @override
  Future<bool> toggleFollow(bool follow) async {
    try {
      if (follow) {
        await http.dio.post('$_basePath/unfollow');
        return false;
      } else {
        await http.dio.post('$_basePath/follow');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ toggleFollow failed: $e');
      return follow;
    }
  }

  // ============ STREAMS ============

  @override
  Stream<Duration> watchLiveClock() {
    ensureWiredOnce();
    return _clockCtrl.stream;
  }

  @override
  Stream<int> watchViewerCount() {
    ensureWiredOnce();
    return _viewerCtrl.stream;
  }

  @override
  Stream<ChatMessage> watchChat() {
    ensureWiredOnce();
    return _chatCtrl.stream;
  }

  @override
  Stream<GuestJoinNotice> watchGuestJoins() {
    ensureWiredOnce();
    return _guestCtrl.stream;
  }

  @override
  Stream<GiftNotice> watchGifts() {
    ensureWiredOnce();
    return _giftCtrl.stream;
  }

  @override
  Stream<bool> watchPause() {
    ensureWiredOnce();
    return _pauseCtrl.stream;
  }

  @override
  Stream<void> watchEnded() {
    ensureWiredOnce();
    return _endedCtrl.stream;
  }

  @override
  Stream<bool> watchMyApproval() {
    ensureWiredOnce();
    return _myApprovalCtrl.stream;
  }

  @override
  Stream<String> watchErrors() {
    ensureWiredOnce();
    return _errorCtrl.stream;
  }

  @override
  Stream<String> watchParticipantRoleChanges() {
    ensureWiredOnce();
    return _participantRoleCtrl.stream;
  }

  @override
  Stream<String> watchParticipantRemovals() {
    ensureWiredOnce();
    return _participantRemovedCtrl.stream;
  }

  @override
  Stream<GiftBroadcast> watchGiftBroadcasts() {
    ensureWiredOnce();
    return _giftBroadcastCtrl.stream;
  }

  Stream<String?> watchActiveGuestUuid() {
    ensureWiredOnce();
    return _activeGuestCtrl.stream;
  }

  // ============ WIRING & EVENT HANDLING ============

  Future<void> ensureWiredOnce() async {
    if (_wired) return;
    if (_wiringFuture != null) return await _wiringFuture;

    _wiringFuture = _wire();
    try {
      await _wiringFuture;
    } finally {
      _wiringFuture = null;
    }
  }

  Future<void> _wire() async {
    if (_wired) return;
    if (_isWiring) {
      await _wiringFuture;
      return;
    }

    _wireStartedAt = DateTime.now();
    _isWiring = true;

    try {
      await _wireInternal();
    } catch (e, stack) {
      debugPrint('❌ _wire failed: $e');
      debugPrint('Stack: $stack');
      _isWiring = false;
      _wiringFuture = null;
      rethrow;
    }
  }

  Future<void> _wireInternal() async {
    debugPrint('🔌 _wireInternal: Starting wiring');

    try {
      // 1. Check livestream status
      final statusRes = await http.dio.get('${_basePath}/status');
      final statusData = _asMap(statusRes.data);

      final isEnded =
          statusData['has_ended'] == true ||
          statusData['ended_at'] != null ||
          statusData['status'] == 'ended';

      if (isEnded) {
        debugPrint('⚠️ Live has already ended on server');
        _endedCtrl.add(null);
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Could not check live status: $e');
    }

    try {
      // 2. Auto-join as audience (viewer count)
      debugPrint('🔌 Auto-joining as audience...');
      final enterRes = await http.dio.post('$_basePath/enter');
      final enterData = _asMap(enterRes.data);

      final viewers = (enterData['viewers'] ?? 0) as int;
      _viewerCtrl.add(viewers);
      debugPrint('🔌 Enter successful, viewers: $viewers');
      _myApprovalCtrl.add(true);

      // 3. GET RTC CREDENTIALS (CRITICAL STEP!)
      debugPrint('🔌 Fetching RTC credentials...');
      final rtcRes = await http.dio.get(
        '$_basePath/rtc',
        queryParameters: {'role': 'audience'},
      );
      final rtcData = _asMap(rtcRes.data);

      debugPrint('🎯 RTC Credentials received:');
      debugPrint('   App ID: ${rtcData['app_id']}');
      debugPrint('   Channel: ${rtcData['channel']}');
      debugPrint('   RTC UID: ${rtcData['rtc_uid']}');
      debugPrint('   Token: ${rtcData['rtc_token']?.substring(0, 20)}...');

      // 4. Join Agora channel with credentials
      debugPrint('🔌 Joining Agora channel...');
      await agoraViewerService.joinAudience(
        appId: (rtcData['app_id'] ?? '').toString(),
        channel: (rtcData['channel'] ?? '').toString(),
        uidType: 'numeric', // Using numeric UIDs
        uid: (rtcData['rtc_uid'] ?? '0').toString(),
        rtcToken: (rtcData['rtc_token'] ?? '').toString(),
      );
      // 5. SET HOST UID IF KNOWN (NEW)
      // Check if backend provides host UID
      if (rtcData['rtc_uid'] != null) {
        final hostUid = int.tryParse('${rtcData['host_uid']}');
        if (hostUid != null) {
          debugPrint('🎯 Setting host UID from backend: $hostUid');
          agoraViewerService.hostUid.value = hostUid;
          // agoraViewerService._hasVideo.value = true;
        }
      }
      debugPrint('✅ Successfully joined Agora channel');
    } catch (e) {
      debugPrint('❌ Auto-join or RTC setup failed: $e');
      _myApprovalCtrl.add(false);
      if (e is DioException) {
        final errorMessage = _extractErrorMessage(e);
        if (errorMessage.isNotEmpty) {
          _errorCtrl.add(errorMessage);
        }
        debugPrint('Dio Error Details:');
        debugPrint('  Status: ${e.response?.statusCode}');
        debugPrint('  Data: ${e.response?.data}');
        debugPrint('  Message: ${e.message}');
      }
    }

    final id = livestreamIdNumeric;
    final chMeta = 'live.$id.meta';
    final chChat = 'live.$id.chat';
    final chJoin = 'live.$id.join';
    final chRoot = 'live.$id';
    final chGifts = 'live.$id.gifts';

    debugPrint(
      '🔌 Subscribing to channels: $chMeta, $chChat, $chRoot, $chGifts',
    );

    await Future.wait([
      pusher.subscribe(chMeta),
      pusher.subscribe(chChat),
      pusher.subscribe(chJoin),
      pusher.subscribe(chRoot),
      pusher.subscribe(chGifts),
    ]);

    _boundEventKeys.clear();

    void _bindEvent(String channel, String event, PusherCallback handler) {
      final key = '$channel::$event';

      if (_boundEventKeys.contains(key)) {
        debugPrint('⚠️ Event already bound: $key');
        return;
      }

      _boundEventKeys.add(key);

      debugPrint('🔗 Binding: $channel -> $event');

      try {
        // CRITICAL FIX: Use PusherCallback type
        final pusherCallback = (Map<String, dynamic> data) {
          debugPrint('🔄 Event received in callback');
          debugPrint('   Channel: $channel, Event: $event');
          debugPrint('   Data: $data');

          _logEvent(channel, event, data);

          // REMOVE VALIDATION TEMPORARILY
          // if (data.isEmpty) {
          //   debugPrint('⚠️ Ignoring empty event: $channel -> $event');
          //   return;
          // }

          // Call handler directly
          try {
            handler(data);
            debugPrint('✅ Handler executed');
          } catch (e) {
            debugPrint('❌ Handler error: $e');
          }
        };

        // Bind with the callback
        pusher.bind(channel, event, pusherCallback);

        debugPrint('✅ Bound successfully');
      } catch (e) {
        debugPrint('❌ Failed to bind: $e');
        _boundEventKeys.remove(key);
      }
    }

    // Event handlers
    _bindEvent(chMeta, 'participant.added', (m) async {
      final data = _asMap(m);
      final currentUuid = await _getCurrentUserUuid();
      final participantUuid = data['user_uuid']?.toString();

      if (participantUuid == currentUuid) {
        final role = data['role']?.toString() ?? 'audience';
        debugPrint('🎯 Current user added as: $role');
        _participantRoleCtrl.add(role);
      }
    });

    _bindEvent(chRoot, 'gift.sent', (m) {
      debugPrint('🎁 Gift.sent: $m');
      if (m.isEmpty) return;

      try {
        final giftMap = _asMap(m);
        final b = GiftBroadcast.fromJson(giftMap);

        if (b.giftCode.isEmpty || b.coinsSpent <= 0) {
          debugPrint('⚠️ Invalid gift data');
          return;
        }

        _giftBroadcastCtrl.add(b);
        _giftCtrl.add(
          GiftNotice(
            from: b.senderDisplayName,
            giftName: b.giftCode,
            coins: b.coinsSpent,
          ),
        );
        debugPrint(
          '🎁 Gift processed: ${b.giftCode} from ${b.senderDisplayName}',
        );
      } catch (e) {
        debugPrint('❌ gift.sent parse failed: $e');
      }
    });

    _bindEvent(chMeta, 'participant.removed', (m) async {
      final data = _asMap(m);
      final currentUuid = await _getCurrentUserUuid();
      final participantUuid = data['user_uuid']?.toString();
      final reason = data['reason']?.toString() ?? 'removed_by_host';

      debugPrint(
        '🎯 participant.removed received for: $participantUuid (reason: $reason)',
      );

      if (_isRoleChangeInProgress && participantUuid == currentUuid) {
        debugPrint('⚠️ Skipping removal event during role change promotion');
        return;
      }

      if (participantUuid == currentUuid) {
        debugPrint('🎯 CURRENT USER REMOVED - Stopping all streams');

        // 1. IMMEDIATELY stop Agora
        try {
          agoraViewerService.leave();
          debugPrint('✅ Agora left');
        } catch (e) {
          debugPrint('⚠️ Error leaving Agora: $e');
        }

        // 2. Unsubscribe from ALL Pusher channels
        try {
          await pusher.unsubscribeAll();
          debugPrint('✅ Unsubscribed from all Pusher channels');
        } catch (e) {
          debugPrint('⚠️ Error unsubscribing from Pusher: $e');
        }

        // 3. Cancel clock
        cancelClock();

        // 4. Clear all event handlers
        _boundEventKeys.clear();

        // 5. Add to removal stream (for UI to show overlay)
        _participantRemovedCtrl.add(reason);

        // 6. Dispose repository immediately
        dispose();

        debugPrint('✅ User fully removed from livestream');
      }

      if (participantUuid != null && participantUuid == _activeGuestUuid) {
        debugPrint('🎯 Active guest removed: $participantUuid');
        _activeGuestUuid = null;
        _activeGuestCtrl.add(null);
      }
    });

    // In the participant.role_changed handler:

    _bindEvent(chMeta, 'participant.role_changed', (m) async {
      _isRoleChangeInProgress = true;

      try {
        final data = _asMap(m);
        final currentUuid = await _getCurrentUserUuid();
        final participantUuid = data['user_uuid']?.toString();
        final newRole = data['role']?.toString()?.toLowerCase() ?? 'audience';

        debugPrint('🎯 Role change: $participantUuid -> $newRole');

        // Track current user's role
        if (participantUuid == currentUuid) {
          _participantRoleCtrl.add(newRole);

          if (newRole == 'guest' || newRole == 'cohost') {
            // Current user promoted - get publisher RTC
            await _promoteCurrentUserToGuest();
          } else if (newRole == 'viewer' || newRole == 'audience') {
            // Current user demoted
            await _demoteCurrentUserToAudience();
          }
        } else {
          // Another user's role changed
          if (newRole == 'guest' || newRole == 'cohost') {
            // Another user became guest - update UI to show guest video
            _activeGuestUuid = participantUuid;
            _activeGuestCtrl.add(_activeGuestUuid);

            // 🔥 CRITICAL: Ensure we're subscribed to see the guest
            // The remote user will join automatically, we just need to refresh
            // No need for extra API call - Agora auto-subscribes to remote users
            debugPrint('🎯 Remote guest joined: $participantUuid');
          } else if (participantUuid == _activeGuestUuid) {
            // The active guest was demoted
            _activeGuestUuid = null;
            _activeGuestCtrl.add(null);
            debugPrint('🎯 Remote guest left/demoted');
          }
        }
      } catch (e) {
        debugPrint('❌ Role change error: $e');
      } finally {
        Future.delayed(const Duration(seconds: 2), () {
          _isRoleChangeInProgress = false;
        });
      }
    });

    _bindEvent(chMeta, 'viewer.count', (m) {
      final data = _asMap(m);
      final raw = data['count'] ?? data['viewers'] ?? 0;
      final viewers = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
      debugPrint('👁️ Viewer count: $viewers');
      _viewerCtrl.add(viewers);
    });

    _bindEvent(chChat, 'chat.message', (m) {
      debugPrint('💬 Chat message: $m');
      _handleChatMessage(m);
    });

    _bindEvent(chRoot, 'live.ended', (m) {
      debugPrint('🔴 Live ended');
      _endedCtrl.add(null);
    });

    _bindEvent(chMeta, 'live.paused', (Map<String, dynamic> data) {
      debugPrint('🎯 [LIVE.PAUSED HANDLER - DIRECT]');
      debugPrint('   Raw data: $data');
      debugPrint('   Data type: ${data.runtimeType}');

      // Check if data is valid
      if (data.isEmpty) {
        debugPrint('❌ WARNING: Empty data received');
        // Even if empty, maybe we should still process?
        // The working LiveSessionRepositoryImpl doesn't check for empty!
      }

      // Try to extract paused value
      bool paused;
      if (data.containsKey('paused')) {
        paused = data['paused'] == true;
      } else {
        // Try different key names
        paused =
            data['is_paused'] == true ||
            data['pause'] == true ||
            false; // Default to false
        debugPrint('   Using fallback paused detection: $paused');
      }

      debugPrint('⏸️ Live paused: $paused');

      // Check stream controller
      if (_pauseCtrl.isClosed) {
        debugPrint('❌ ERROR: _pauseCtrl is closed');
        return;
      }

      try {
        _pauseCtrl.add(paused);
        debugPrint('✅ Added to _pauseCtrl stream');
      } catch (e) {
        debugPrint('❌ ERROR adding to _pauseCtrl: $e');
      }
    });

    await _hydrateRecentChat();
    _startClock();

    _wired = true;
    _hasStarted = true;
    _isWiring = false;
    _wiringFuture = null;

    final elapsed = DateTime.now().difference(_wireStartedAt!);
    debugPrint('✅ Wiring completed in ${elapsed.inMilliseconds}ms');
    debugPrint('✅ Bound ${_boundEventKeys.length} events');
  }

  // Helper method for current user promotion
  Future<void> _promoteCurrentUserToGuest() async {
    debugPrint('🎯 Fetching publisher RTC for promotion...');
    try {
      final rtcRes = await http.dio.get(
        '$_basePath/rtc',
        queryParameters: {'role': 'publisher'},
      );
      final rtcData = _asMap(rtcRes.data);

      await agoraViewerService.promoteToCoHost(
        rtcToken: rtcData['rtc_token'].toString(),
      );
      debugPrint('✅ Promotion successful');
    } catch (e) {
      debugPrint('❌ Promotion failed: $e');
    }
  }

  // Helper method for current user demotion
  Future<void> _demoteCurrentUserToAudience() async {
    debugPrint('🎯 Demoting current user to audience...');
    try {
      await agoraViewerService.demoteToAudience();

      // Get new audience token
      final rtcRes = await http.dio.get(
        '$_basePath/rtc',
        queryParameters: {'role': 'audience'},
      );
      final rtcData = _asMap(rtcRes.data);

      await agoraViewerService.renewToken(rtcData['rtc_token'].toString());
      debugPrint('✅ Demotion successful');
    } catch (e) {
      debugPrint('❌ Demotion failed: $e');
    }
  }

  void _handleChatMessage(Map<String, dynamic> raw) {
    try {
      if (raw.isEmpty) return;

      final m = _asMap(raw);
      final chatData = (m['chat'] is Map) ? _asMap(m['chat']) : m;

      if (chatData.isEmpty) return;

      final text = (chatData['text'] ?? '').toString();
      if (text.isEmpty) return;

      String username = 'user';
      String? avatarUrl;

      if (chatData['user'] is Map) {
        final user = _asMap(chatData['user']);
        username = (user['user_slug'] ?? user['slug'] ?? user['name'] ?? 'user')
            .toString();
        avatarUrl = user['avatar']?.toString();
      } else {
        username = chatData['user']?.toString() ?? 'user';
      }

      final messageId =
          (chatData['id'] ?? DateTime.now().microsecondsSinceEpoch.toString())
              .toString();

      debugPrint('💬 Chat: $username: $text');

      _chatCtrl.add(ChatMessage(id: messageId, username: username, text: text));
    } catch (e) {
      debugPrint('❌ Failed to process chat: $e');
    }
  }

  Future<void> _hydrateRecentChat() async {
    try {
      final res = await http.dio.get(
        '$_basePath/chats',
        queryParameters: {'limit': 50},
      );
      final data = res.data;
      final List list = (data is List) ? data : (jsonDecode('$data') as List);

      for (final e in list) {
        final m = (e as Map).cast<String, dynamic>();
        _chatCtrl.add(
          ChatMessage(
            id: '${m['id']}',
            username: m['user'] is Map
                ? '${(m['user'] as Map)['user_slug'] ?? (m['user'] as Map)['name'] ?? 'user'}'
                : '${m['user']}',
            text: '${m['text']}',
            isHost: hostSlug == m['user'],
          ),
        );
      }
      debugPrint('💬 Loaded ${list.length} chat messages');
    } catch (e) {
      debugPrint('⚠️ Failed to hydrate chat: $e');
    }
  }

  void _startClock() {
    _clockTimer?.cancel();
    final base = startedAt ?? DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _clockCtrl.add(DateTime.now().difference(base));
    });
  }

  void cancelClock() {
    _clockTimer?.cancel();
    _clockTimer = null;
    debugPrint('⏰ Clock cancelled');
  }

  // ============ HELPERS ============

  Future<String?> _getCurrentUserUuid() async {
    try {
      return await authLocalDataSource.getCurrentUserUuid();
    } catch (e) {
      debugPrint('⚠️ Failed to get user UUID: $e');
      return null;
    }
  }

  String _extractErrorMessage(DioException e) {
    try {
      if (e.response?.data is Map) {
        final data = e.response!.data as Map;
        return data['message']?.toString() ??
            data['error']?.toString() ??
            'An error occurred';
      }
      return e.message ?? 'Connection error';
    } catch (_) {
      return 'An unexpected error occurred';
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    debugPrint('   🔧 _asMap called with: $data');
    debugPrint('   Input type: ${data.runtimeType}');

    if (data is Map<String, dynamic>) {
      debugPrint('   ✅ Already Map<String, dynamic>');
      return data;
    }
    if (data is Map) {
      debugPrint('   ✅ Casting Map to Map<String, dynamic>');
      return data.cast<String, dynamic>();
    }
    if (data is String) {
      debugPrint('   📝 Parsing string to JSON...');
      try {
        final decoded = jsonDecode(data);
        debugPrint('   Decoded: $decoded');
        debugPrint('   Decoded type: ${decoded.runtimeType}');

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.cast<String, dynamic>();
        }
      } catch (e) {
        debugPrint('   ❌ JSON decode error: $e');
      }
    }

    debugPrint('   ⚠️ Returning empty map');
    return <String, dynamic>{};
  }

  String _genIdempotencyKey() {
    final r = Random();
    final ts = DateTime.now().microsecondsSinceEpoch;
    final salt = List.generate(
      8,
      (_) => r.nextInt(16),
    ).map((n) => n.toRadixString(16)).join();
    return 'ml-$ts-$salt';
  }

  void _logEvent(String channel, String event, Map<String, dynamic> data) {
    final timestamp = DateTime.now();
    final logEntry = '[$timestamp] $channel -> $event: ${data.toString()}';
    _eventHistory.add(logEntry);

    if (_eventHistory.length > 50) {
      _eventHistory.removeAt(0);
    }

    debugPrint('📡 EVENT: $logEntry');
  }

  // ============ CLEANUP ============

  @override
  void dispose() {
    try {
      cancelClock();
      http.dio.post('$_basePath/leave').ignore();
      pusher.unsubscribeAll();
      // agoraViewerService.disposeEngine();
    } catch (_) {}

    _giftBroadcastCtrl.close();
    _clockCtrl.close();
    _viewerCtrl.close();
    _chatCtrl.close();
    _guestCtrl.close();
    _giftCtrl.close();
    _pauseCtrl.close();
    _endedCtrl.close();
    _myApprovalCtrl.close();
    _activeGuestCtrl.close();
    _errorCtrl.close();
    _participantRoleCtrl.close();
    _participantRemovedCtrl.close();

    debugPrint('🗑️ Repository disposed (clean, no video rendering)');
  }

  // ============ VIDEO SURFACE PROVIDER REMOVED ============
  // ❌ NO MORE: buildHostVideo(), buildGuestVideo(), buildLocalPreview()
  // ❌ NO MORE: setMicEnabled(), setCamEnabled()
  // These are now handled by LiveStreamService
}
