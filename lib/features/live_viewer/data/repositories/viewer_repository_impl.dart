import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';

import '../../domain/entities.dart';
import '../../domain/repositories/viewer_repository.dart';
import '../../domain/video_surface_provider.dart';

class ViewerRepositoryImpl implements ViewerRepository, VideoSurfaceProvider {
  final DioClient http;
  final PusherService pusher;
  final AuthLocalDataSource authLocalDataSource;

  /// REST path segment: UUID or numeric (both accepted by backend)
  final String livestreamParam;

  /// Pusher channel id: MUST be numeric
  final int livestreamIdNumeric;

  /// Agora channel name (e.g., "live_ABC...")
  final String channelName;

  final HostInfo? initialHost;
  final DateTime? startedAt;
  String? toUserUuid; // set from router or a fetch if needed
  final String? hostUserUuid;

  String? get hostUuid => hostUserUuid;

  ViewerRepositoryImpl({
    required this.http,
    required this.pusher,
    required this.authLocalDataSource,
    required this.livestreamParam,
    required this.livestreamIdNumeric,
    required this.channelName,
    this.hostUserUuid,
    this.initialHost,
    this.startedAt,
  }) : _rtc = AgoraViewerService(
         onTokenRefresh: (_) async {
           final token = await _fetchRtcTokenStatic(
             http: http,
             livestreamParam: livestreamParam,
             role: "audience",
           );
           return token;
         },
       );

  // === GIFTS: controllers & cache ===
  final _giftBroadcastCtrl = StreamController<GiftBroadcast>.broadcast();
  List<GiftItem> _giftCatalogCache = const [];
  String? _giftCatalogVersion;

  @override
  Stream<GiftBroadcast> watchGiftBroadcasts() {
    _ensureWiredOnce();
    return _giftBroadcastCtrl.stream;
  }

  // ===== RTC viewer service (renders host video when joined) =====
  final AgoraViewerService _rtc;

  // ===== Streams =====
  final _clockCtrl = StreamController<Duration>.broadcast();
  final _viewerCtrl = StreamController<int>.broadcast();
  final _chatCtrl = StreamController<ChatMessage>.broadcast();
  final _guestCtrl = StreamController<GuestJoinNotice>.broadcast();
  final _giftCtrl = StreamController<GiftNotice>.broadcast();
  final _pauseCtrl = StreamController<bool>.broadcast();
  final _endedCtrl = StreamController<void>.broadcast();
  final _myApprovalCtrl = StreamController<bool>.broadcast();
  final _activeGuestCtrl = StreamController<String?>.broadcast();

  // ✅ FIXED: Initialize missing stream controllers
  final _errorCtrl = StreamController<String>.broadcast();
  final _participantRoleCtrl = StreamController<String>.broadcast();
  final _participantRemovedCtrl = StreamController<String>.broadcast();

  String? _activeGuestUuid;
  Timer? _clockTimer;
  Future<void>? _wiringFuture;
  bool _wired = false;

  String? _myJoinRequestId;

  String get _basePath => '/api/v1/live/$livestreamParam';
  @override
  ValueListenable<bool> get hostHasVideo => _rtc.hostHasVideo;
  @override
  ValueListenable<bool> get guestHasVideo => _rtc.guestHasVideo;
  // ✅ ADD MUTE STATE STREAMS FOR UI
  final _micStateCtrl = StreamController<bool>.broadcast();
  final _camStateCtrl = StreamController<bool>.broadcast();

  @override
  Stream<bool> watchMicState() {
    _ensureWiredOnce();
    return _micStateCtrl.stream;
  }

  @override
  Stream<bool> watchCamState() {
    _ensureWiredOnce();
    return _camStateCtrl.stream;
  }

  // ========= Host info =========
  @override
  Future<HostInfo> fetchHostInfo() async {
    if (initialHost != null) return initialHost!;
    return const HostInfo(
      name: 'Host',
      title: 'Live',
      subtitle: '',
      badge: 'Superstar',
      avatarUrl: 'https://via.placeholder.com/120x120.png?text=LIVE',
      isFollowed: false,
    );
  }

  // ========= Wiring (coalesced, idempotent) =========
  Future<void> _ensureWiredOnce() async {
    _wiringFuture ??= _wire();
    await _wiringFuture;
  }

  Future<void> _wire() async {
    if (_wired) return;
    // Add debug call here
    debugPusherStatus();
    // Auto-join as audience immediately
    try {
      final enterRes = await http.dio.post('$_basePath/enter');
      final enterData = (enterRes.data is Map)
          ? (enterRes.data as Map)
          : jsonDecode(enterRes.data as String) as Map;
      final v = (enterData['viewers'] ?? 0) as int;
      _viewerCtrl.add(v);

      final creds = await _fetchRtcCreds(role: 'audience');
      debugPrint(
        '[RTC] Auto-joining as audience: appId=${creds.appId}, ch=${creds.channel}, '
        'uidType=${creds.uidType}, uid=${creds.uid}, token.len=${creds.token.length}',
      );

      await _rtc.joinAudience(
        appId: creds.appId,
        channel: creds.channel,
        uidType: creds.uidType,
        uid: creds.uid,
        rtcToken: creds.token,
      );

      _myApprovalCtrl.add(true);
    } catch (e) {
      debugPrint('⚠️ Auto-join as audience failed: $e');
      _myApprovalCtrl.add(false);
      if (e is DioException) {
        final errorMessage = _extractErrorMessage(e);
        if (errorMessage.isNotEmpty) {
          _errorCtrl.add(errorMessage);
        }
      }
    }

    final id = livestreamIdNumeric;
    final chMeta = 'live.$id.meta';
    final chChat = 'live.$id.chat';
    final chJoin = 'live.$id.join';
    final chRoot = 'live.$id';
    final chGifts = 'live.$id.gifts';
    // keep track of which channel+event pairs we've already bound so we don't double-bind
    final Set<String> _boundEventKeys = <String>{};
    await pusher.subscribe(chMeta);
    await pusher.subscribe(chChat);
    await pusher.subscribe(chJoin);
    await pusher.subscribe(chRoot);
    await pusher.subscribe(chGifts);

    // ✅ ENHANCED: Add proper error handling and debug logging for event bindings
    void _bindEvent(
      String channel,
      String event,
      Function(Map<String, dynamic>) handler,
    ) {
      try {
        pusher.bind(channel, event, handler);
        debugPrint('✅ Bound event: $channel -> $event');
      } catch (e) {
        debugPrint('❌ Failed to bind event $channel -> $event: $e');
      }
    }

    // ========= PARTICIPANT EVENTS HANDLING =========
    _bindEvent(chMeta, 'participant.added', (m) async {
      debugPrint('🎯 participant.added received: $m');
      final participantData = m is Map
          ? m.cast<String, dynamic>()
          : <String, dynamic>{};
      final currentUserUuid = await _getCurrentUserUuid();
      final participantUuid = participantData['user_uuid']?.toString();

      if (participantUuid == currentUserUuid) {
        final role = participantData['role']?.toString() ?? 'audience';
        debugPrint('🎯 Current user added as: $role');
        _participantRoleCtrl.add(role);
      }
    });

    // NEW: gift.sent broadcast
    _bindEvent(chGifts, 'gift.sent', (m) {
      try {
        final b = GiftBroadcast.fromJson((m as Map).cast<String, dynamic>());
        _giftBroadcastCtrl.add(b);
        // Also emit legacy GiftNotice for your existing toast if you want:
        _giftCtrl.add(
          GiftNotice(
            from: b.senderDisplayName,
            giftName: b.giftCode,
            coins: b.coinsSpent,
          ),
        );
      } catch (e) {
        debugPrint('❌ gift.sent parse failed: $e');
      }
    });

    _bindEvent(chMeta, 'participant.removed', (m) async {
      debugPrint('🎯 participant.removed received: $m');
      final participantData = m is Map
          ? m.cast<String, dynamic>()
          : <String, dynamic>{};
      final currentUserUuid = await _getCurrentUserUuid();
      final participantUuid = participantData['user_uuid']?.toString();

      if (participantUuid == currentUserUuid) {
        final reason =
            participantData['reason']?.toString() ?? 'removed_by_host';
        debugPrint('🎯 Current user removed: $reason');
        await _rtc.leave();
        _participantRemovedCtrl.add(reason);
      }

      // If active guest was removed, clear it for everyone
      if (participantUuid != null && participantUuid == _activeGuestUuid) {
        _activeGuestUuid = null;
        _activeGuestCtrl.add(null);
      }
    });

    _bindEvent(chMeta, 'participant.role_changed', (m) async {
      debugPrint('🎯 participant.role_changed received: $m');
      final participantData = m is Map
          ? m.cast<String, dynamic>()
          : <String, dynamic>{};
      final currentUserUuid = await _getCurrentUserUuid();
      final participantUuid = participantData['user_uuid']?.toString();

      if (participantUuid == currentUserUuid) {
        final newRole = participantData['role']?.toString() ?? 'audience';
        debugPrint('🎯 Current user role changed to: $newRole');
        await _handleRoleChange(newRole);
        _participantRoleCtrl.add(newRole);
      }

      // Track global active guest for layout
      final role = (participantData['role']?.toString() ?? '').toLowerCase();
      if (role == 'guest' || role == 'cohost') {
        _activeGuestUuid = participantUuid;
        _activeGuestCtrl.add(_activeGuestUuid);
        debugPrint('🎯 Active guest set to: $_activeGuestUuid');
      } else if (participantUuid != null &&
          participantUuid == _activeGuestUuid) {
        _activeGuestUuid = null;
        _activeGuestCtrl.add(null);
        debugPrint('🎯 Active guest cleared');
      }
    });

    // Add other existing event bindings with _bindEvent wrapper...
    _bindEvent(chMeta, 'viewer.count', (m) {
      final raw = (m['count'] ?? m['viewers'] ?? 0);
      final v = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
      _viewerCtrl.add(v);
    });

    // Add these chat message bindings - they're missing!
    _bindEvent(chChat, 'chat.message', (m) {
      debugPrint('🎯 Chat message received on $chChat: $m');
      _handleChatMessage(m);
    });

    // ========= LIVE ENDED EVENT BINDINGS =========
    _bindEvent(chRoot, 'live.ended', (m) {
      debugPrint('🔴 Live ended event received: $m');
      _endedCtrl.add(null);
    });

    _bindEvent(chMeta, 'live.paused', (m) {
      final paused = (m['paused'] ?? false) == true;
      _pauseCtrl.add(paused);
    });

    // ... rest of existing event bindings

    await _hydrateRecentChat();
    _startClock();
    _wired = true;

    debugPrint('✅ Pusher wiring completed successfully');
  }

  /// Fetch the user's wallet details and return the coin balance (or null on error)
  @override
  Future<int?> fetchWalletBalance() async {
    try {
      final res = await http.dio.get('/api/v1/wallet');
      final m = (res.data is Map)
          ? res.data as Map
          : jsonDecode('${res.data}') as Map;
      final data = (m['data'] is Map)
          ? (m['data'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final balance = data['balance'];
      if (balance is num) return balance.toInt();
      if (balance is String) return int.tryParse(balance);
      return null;
    } catch (e) {
      debugPrint('⚠️ fetchWalletBalance failed: $e');
      return null;
    }
  }

  // === GIFTS: catalog fetch ===
  @override
  Future<(List<GiftItem>, String?)> fetchGiftCatalog() async {
    try {
      final res = await http.dio.get('/api/v1/wallet/gifts');
      // print(res.data);
      final data = (res.data is Map)
          ? res.data as Map
          : jsonDecode('${res.data}') as Map;
      final List list = (data['data'] as List? ?? const []);
      final items = list
          .map((e) => GiftItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      _giftCatalogCache = items;
      _giftCatalogVersion = data['catalog_version']?.toString();
      return (items, _giftCatalogVersion);
    } catch (e) {
      debugPrint('⚠️ fetchGiftCatalog failed: $e');
      // return cache if any
      return (_giftCatalogCache, _giftCatalogVersion);
    }
  }

  String _genIdempotencyKey() {
    // lightweight id generator (no new dependency)
    final r = Random();
    final ts = DateTime.now().microsecondsSinceEpoch;
    final salt = List.generate(
      8,
      (_) => r.nextInt(16),
    ).map((n) => n.toRadixString(16)).join();
    return 'ml-$ts-$salt';
    // Note: You also have IdempotencyInterceptor for headers; backend requires body field too.
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
      final m = (res.data is Map)
          ? res.data as Map
          : jsonDecode('${res.data}') as Map;
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

  // ✅ FIXED: Add these new stream getters to the repository interface
  @override
  Stream<String> watchErrors() {
    _ensureWiredOnce();
    return _errorCtrl.stream;
  }

  @override
  Stream<String> watchParticipantRoleChanges() {
    _ensureWiredOnce();
    return _participantRoleCtrl.stream;
  }

  @override
  Stream<String> watchParticipantRemovals() {
    _ensureWiredOnce();
    return _participantRemovedCtrl.stream;
  }

  // Helper method to get current user UUID
  Future<String?> _getCurrentUserUuid() async {
    try {
      return await authLocalDataSource.getCurrentUserUuid();
    } catch (e) {
      debugPrint('⚠️ Failed to get current user UUID: $e');
      return null;
    }
  }

  void _handleChatMessage(Map<String, dynamic> raw) {
    try {
      debugPrint('🎯 Processing chat message: $raw');

      final m = _asMap(raw);
      final chatData = (m['chat'] is Map) ? _asMap(m['chat']) : m;

      final text = (chatData['text'] ?? '').toString();
      if (text.isEmpty) {
        debugPrint('⚠️ Empty chat message text, skipping');
        return;
      }

      String username = 'user';
      String? avatarUrl;

      // Parse user info from different possible structures
      if (chatData['user'] is Map) {
        final user = _asMap(chatData['user']);
        username = (user['user_slug'] ?? user['slug'] ?? user['name'] ?? 'user')
            .toString();
        avatarUrl = user['avatar']?.toString();
      } else {
        username = chatData['user']?.toString() ?? 'user';
      }

      final messageId =
          (chatData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString())
              .toString();

      debugPrint('💬 Chat parsed - $username: $text');

      _chatCtrl.add(
        ChatMessage(
          id: messageId,
          username: username,
          text: text,
          // avatarUrl: avatarUrl, // Add this if your ChatMessage supports it
        ),
      );
    } catch (e) {
      debugPrint('❌ Failed to process chat message: $e');
      debugPrint('   Raw data: $raw');
    }
  }

  // ✅ IMPROVED: Helper method to handle role changes
  Future<void> _handleRoleChange(String newRole) async {
    try {
      debugPrint('🔄 Handling role change to: $newRole');

      if (newRole == 'guest' || newRole == 'cohost') {
        // ✅ NOTIFY UI ABOUT DEFAULT MUTE STATE
        _micStateCtrl.add(false); // Mic muted
        _camStateCtrl.add(false); // Camera muted

        debugPrint('🔇 Default mute state set for guest promotion');

        // Promote to publisher - service will handle default mute
        final creds = await _fetchRtcCreds(role: 'publisher');
        debugPrint('🔄 Promoting to co-host/guest with default mute');
        await _rtc.promoteToCoHost(rtcToken: creds.token);

        debugPrint(
          '✅ Successfully promoted to co-host/guest (mic/cam muted by default)',
        );

        // ✅ USER FEEDBACK
        _errorCtrl.add(
          'You are now a guest. Mic and camera are muted for privacy.',
        );
      } else {
        // Demote to audience
        debugPrint('🔄 Demoting to audience');
        await _rtc.demoteToAudience();

        // Reset UI state
        _micStateCtrl.add(false);
        _camStateCtrl.add(false);

        // Get new audience token and renew
        final audToken = await _fetchRtcTokenStatic(
          http: http,
          livestreamParam: livestreamParam,
          role: 'audience',
        );
        await _rtc.engine?.renewToken(audToken);
        debugPrint('✅ Successfully demoted to audience');
      }
    } catch (e, stack) {
      debugPrint('❌ Role change handling failed: $e');
      debugPrint('Stack trace: $stack');
      _errorCtrl.add('Failed to handle role change: $e');

      // Recovery logic...
    }
  }

  // Helper method to extract error messages from DioException
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

  // Helper method to get removal message based on reason
  String _getRemovalMessage(String reason) {
    switch (reason) {
      case 'removed_by_host':
        return 'You have been removed from the stream by the host';
      case 'violated_guidelines':
        return 'You have been removed for violating community guidelines';
      case 'banned':
        return 'You have been banned from this stream';
      default:
        return 'You have been removed from the stream';
    }
  }

  // ========= Hydration & utils =========
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
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ hydrate chat failed: $e');
    }
  }

  void debugPusherStatus() {
    debugPrint('🔍 Pusher Status Debug:');
    debugPrint('   - Wired: $_wired');
    debugPrint('   - Wiring future: $_wiringFuture');
    pusher.debugSubscriptions();
  }

  void _startClock() {
    _clockTimer?.cancel();
    final base = startedAt ?? DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _clockCtrl.add(DateTime.now().difference(base));
    });
  }

  // ========= Contract (streams) =========
  @override
  Stream<Duration> watchLiveClock() {
    _ensureWiredOnce();
    return _clockCtrl.stream;
  }

  @override
  Stream<int> watchViewerCount() {
    _ensureWiredOnce();
    return _viewerCtrl.stream;
  }

  @override
  Stream<ChatMessage> watchChat() {
    _ensureWiredOnce();
    return _chatCtrl.stream;
  }

  @override
  Stream<GuestJoinNotice> watchGuestJoins() {
    _ensureWiredOnce();
    return _guestCtrl.stream;
  }

  @override
  Stream<GiftNotice> watchGifts() {
    _ensureWiredOnce();
    return _giftCtrl.stream;
  }

  @override
  Stream<bool> watchPause() {
    _ensureWiredOnce();
    return _pauseCtrl.stream;
  }

  @override
  Stream<void> watchEnded() {
    _ensureWiredOnce();
    return _endedCtrl.stream;
  }

  @override
  Stream<bool> watchMyApproval() {
    _ensureWiredOnce();
    return _myApprovalCtrl.stream;
  }

  // ========= Actions =========
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
  Future<int> like() async => 0;

  @override
  Future<int> share() async => 0;

  @override
  Future<void> requestToJoin() async {
    // Implementation commented out as per your code
  }

  @override
  Future<bool> toggleFollow(bool follow) async => !follow;

  // ========= Cleanup =========
  @override
  void dispose() {
    try {
      _clockTimer?.cancel();
      http.dio.post('$_basePath/leave').ignore();
      pusher.unsubscribeAll();
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
    _rtc.leave().ignore();
    _rtc.disposeEngine().ignore();
  }

  // ========= RTC creds helpers =========
  Future<_RtcCreds> _fetchRtcCreds({required String role}) async {
    try {
      final res = await http.dio.get(
        '$_basePath/rtc',
        queryParameters: {'role': role},
      );
      final m = _asMap(res.data);

      if (m['error'] != null) {
        throw DioException(
          requestOptions: RequestOptions(path: '$_basePath/rtc'),
          response: Response(
            requestOptions: RequestOptions(path: '$_basePath/rtc'),
            data: m,
          ),
        );
      }

      return _RtcCreds(
        appId: '${m['agora']?['app_id'] ?? m['app_id']}',
        token: '${m['agora']?['rtc_token'] ?? m['rtc_token']}',
        uidType: '${m['uid_type'] ?? 'uid'}',
        uid: '${m['rtc_uid']}',
        channel: '${m['channel'] ?? channelName}',
      );
    } on DioException catch (e) {
      final errorMessage = _extractErrorMessage(e);
      _errorCtrl.add(errorMessage);
      rethrow;
    }
  }

  static Future<String> _fetchRtcTokenStatic({
    required DioClient http,
    required String livestreamParam,
    required String role,
  }) async {
    final res = await http.dio.get(
      '/api/v1/live/$livestreamParam/rtc',
      queryParameters: {'role': role},
    );
    final m = (res.data is Map)
        ? (res.data as Map)
        : jsonDecode(res.data as String) as Map;
    return '${m['agora']?['rtc_token'] ?? m['rtc_token']}';
  }

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

  // ========= VideoSurfaceProvider =========
  @override
  Widget buildHostVideo() => _rtc.hostVideoView();

  @override
  Widget? buildLocalPreview() => _rtc.localPreviewBubble();

  @override
  Widget buildGuestVideo() => _rtc.guestVideoView();

  @override
  Future<void> setMicEnabled(bool on) => _rtc.setMicEnabled(on);

  @override
  Future<void> setCamEnabled(bool on) => _rtc.setCamEnabled(on);

  // ====== Active guest (global) exposure ======
  Stream<String?> watchActiveGuestUuid() {
    _ensureWiredOnce();
    return _activeGuestCtrl.stream;
  }
}

class _RtcCreds {
  final String appId;
  final String token;
  final String uidType;
  final String uid;
  final String channel;
  _RtcCreds({
    required this.appId,
    required this.token,
    required this.uidType,
    required this.uid,
    required this.channel,
  });
}
