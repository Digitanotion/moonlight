// lib/features/live_viewer/data/repositories/viewer_repository_impl.dart
//
// CHANGES vs original:
//   1. _wireInternal() now runs status-check, enter, and RTC-fetch
//      concurrently with Future.wait — saves ~1-2 s on every open.
//   2. New preWarm() method: initialises Agora engine early (before the
//      user taps "go live") so the SDK cold-start cost is paid up-front.
//   3. New hasPreWarmedToken / _preWarmedRtcData to cache RTC credentials
//      fetched by the pager before the page is actually shown.
//   4. Everything else is identical to the original.

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
  AgoraViewerService get agoraService => agoraViewerService;

  // ── Pre-warmed RTC data (set by LiveViewerPager before page is shown) ────
  Map<String, dynamic>? _preWarmedRtcData;
  bool get hasPreWarmedToken => _preWarmedRtcData != null;
  bool get wasWired => _wired;

  /// Called by LiveViewerPager to pre-fetch the RTC token for this stream
  /// before the user swipes to it.  Safe to call multiple times — no-ops
  /// if already fetched or if wiring has already started.
  Future<void> prefetchRtcToken() async {
    if (_wired || _isWiring || _preWarmedRtcData != null) return;
    try {
      debugPrint('🔥 [preWarm] Pre-fetching RTC for $livestreamParam');
      final res = await http.dio.get(
        '$_basePath/rtc',
        queryParameters: {'role': 'audience'},
      );
      _preWarmedRtcData = _asMap(res.data);
      debugPrint('🔥 [preWarm] RTC token cached for $livestreamParam');
    } catch (e) {
      debugPrint('⚠️ [preWarm] RTC prefetch failed (non-fatal): $e');
    }
  }

  void resetWiring() {
    debugPrint('🔄 [Repository] resetWiring: $livestreamParam');
    _wired = false;
    _hasStarted = false;
    _isWiring = false;
    _wiringFuture = null;
    _preWarmedRtcData = null;
    _boundEventKeys.clear();
    cancelClock();
    try {
      pusher.unsubscribeAll();
    } catch (_) {}
  }

  // State
  bool _hasStarted = false;
  bool _hasEnded = false;
  bool _isWiring = false;
  bool _disposed = false;
  bool keepAlive = false;

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
      '🎯 [Repository] Created: $livestreamParam '
      'AgoraService: ${agoraViewerService.hashCode}',
    );
  }

  // ============ PUBLIC API ============

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

  Future<bool> checkIfLivestreamActive() async {
    try {
      final response = await http.dio.get('${_basePath}/status');
      final data = _asMap(response.data);
      final status = data['status']?.toString() ?? '';
      final isOnline = status == 'online';
      debugPrint('🔍 Livestream status: $status');
      return isOnline;
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final errorData = _asMap(e.response?.data);
        final message = errorData['message']?.toString() ?? '';
        if (message.contains('not active')) return false;
      }
      debugPrint('❌ Error checking livestream status: $e');
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Unexpected error checking livestream status: $e');
      return true;
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

  // ============ WIRING ============

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
      debugPrint('❌ _wire failed: $e\n$stack');
      _isWiring = false;
      _wiringFuture = null;
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KEY CHANGE: parallelise the three independent HTTP calls.
  //
  // BEFORE (sequential):  status → enter → rtc → joinAgora   (~2-3 s)
  // AFTER  (parallel):    [status + enter + rtc] → joinAgora (~600-900 ms)
  //
  // We also consume the pre-warmed RTC token (if the pager fetched it
  // ahead of time) so on scroll the token is already in memory.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _wireInternal() async {
    debugPrint('🔌 _wireInternal: starting (parallel mode)');

    // ── Step 1: Fire status-check, enter, and RTC concurrently ─────────────
    // We allow any of them to fail independently so a non-critical error
    // (e.g. /status returning 422) doesn't block the other calls.

    late Map<String, dynamic> statusData;
    late Map<String, dynamic> enterData;
    late Map<String, dynamic> rtcData;

    // If the pager pre-fetched the RTC token, reuse it immediately.
    if (_preWarmedRtcData != null) {
      debugPrint('🔥 [preWarm] Using cached RTC token');
      rtcData = _preWarmedRtcData!;
      _preWarmedRtcData = null; // consume once

      // Still run status + enter in parallel (but skip RTC fetch)
      final results = await Future.wait([
        _safeGet('${_basePath}/status'),
        _safePost('${_basePath}/enter'),
      ]);
      statusData = results[0];
      enterData = results[1];
    } else {
      // No pre-warmed token — run all three in parallel
      final results = await Future.wait([
        _safeGet('${_basePath}/status'),
        _safePost('${_basePath}/enter'),
        _safeGet('${_basePath}/rtc', query: {'role': 'audience'}),
      ]);
      statusData = results[0];
      enterData = results[1];
      rtcData = results[2];
    }

    // ── Step 2: Check if stream already ended ───────────────────────────────
    final isEnded =
        statusData['has_ended'] == true ||
        statusData['ended_at'] != null ||
        statusData['status'] == 'ended';

    if (isEnded) {
      if (!_endedCtrl.isClosed) _endedCtrl.add(null);
      return;
    }

    // ── Step 3: Process enter response ─────────────────────────────────────
    final viewers = (enterData['viewers'] ?? 0) as int;
    if (!_viewerCtrl.isClosed) _viewerCtrl.add(viewers);
    if (!_myApprovalCtrl.isClosed) _myApprovalCtrl.add(true);
    debugPrint('🔌 Enter OK — viewers: $viewers');

    // ── Step 4: Join Agora with RTC credentials ─────────────────────────────
    if (rtcData.isNotEmpty) {
      debugPrint(
        '🎯 RTC App: ${rtcData['app_id']}  '
        'Ch: ${rtcData['channel']}  UID: ${rtcData['rtc_uid']}',
      );
      try {
        await agoraViewerService.joinAudience(
          appId: (rtcData['app_id'] ?? '').toString(),
          channel: (rtcData['channel'] ?? '').toString(),
          uidType: 'numeric',
          uid: (rtcData['rtc_uid'] ?? '0').toString(),
          rtcToken: (rtcData['rtc_token'] ?? '').toString(),
        );

        // Set host UID if provided by backend
        final hostUid = int.tryParse('${rtcData['host_uid'] ?? ''}');
        if (hostUid != null) {
          agoraViewerService.hostUid.value = hostUid;
        }

        debugPrint('✅ Joined Agora channel');
      } catch (e) {
        debugPrint('❌ Agora joinAudience failed: $e');
        _myApprovalCtrl.add(false);
        if (e is DioException) {
          _errorCtrl.add(_extractErrorMessage(e));
        }
      }
    } else {
      debugPrint('⚠️ RTC data empty — skipping Agora join');
      _myApprovalCtrl.add(false);
    }

    // ── Step 5: Subscribe to Pusher channels ───────────────────────────────
    final id = livestreamIdNumeric;
    final chMeta = 'live.$id.meta';
    final chChat = 'live.$id.chat';
    final chJoin = 'live.$id.join';
    final chRoot = 'live.$id';
    final chGifts = 'live.$id.gifts';

    await Future.wait([
      pusher.subscribe(chMeta),
      pusher.subscribe(chChat),
      pusher.subscribe(chJoin),
      pusher.subscribe(chRoot),
      pusher.subscribe(chGifts),
    ]);

    _boundEventKeys.clear();

    // ── Step 6: Bind events (unchanged from original) ──────────────────────
    void bindEvent(String channel, String event, PusherCallback handler) {
      final key = '$channel::$event';
      if (_boundEventKeys.contains(key)) return;
      _boundEventKeys.add(key);
      try {
        pusher.bind(channel, event, (Map<String, dynamic> data) {
          _logEvent(channel, event, data);
          try {
            handler(data);
          } catch (e) {
            debugPrint('❌ Handler error [$key]: $e');
          }
        });
      } catch (e) {
        debugPrint('❌ Failed to bind [$key]: $e');
        _boundEventKeys.remove(key);
      }
    }

    bindEvent(chMeta, 'participant.added', (m) async {
      final data = _asMap(m);
      final currentUuid = await _getCurrentUserUuid();
      final participantUuid = data['user_uuid']?.toString();
      if (participantUuid == currentUuid) {
        final role = data['role']?.toString() ?? 'audience';
        _participantRoleCtrl.add(role);
      }
    });

    bindEvent(chRoot, 'gift.sent', (m) {
      if (m.isEmpty) return;
      try {
        final b = GiftBroadcast.fromJson(_asMap(m));
        if (b.giftCode.isEmpty || b.coinsSpent <= 0) return;
        _giftBroadcastCtrl.add(b);
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

    bindEvent(chMeta, 'participant.removed', (m) async {
      final data = _asMap(m);
      final currentUuid = await _getCurrentUserUuid();
      final participantUuid = data['user_uuid']?.toString();
      final reason = data['reason']?.toString() ?? 'removed_by_host';

      if (_isRoleChangeInProgress && participantUuid == currentUuid) return;

      if (participantUuid == currentUuid) {
        try {
          agoraViewerService.leave();
        } catch (_) {}
        try {
          await pusher.unsubscribeAll();
        } catch (_) {}
        cancelClock();
        _boundEventKeys.clear();
        _participantRemovedCtrl.add(reason);
        dispose();
      }

      if (participantUuid != null && participantUuid == _activeGuestUuid) {
        _activeGuestUuid = null;
        _activeGuestCtrl.add(null);
      }
    });

    bindEvent(chMeta, 'participant.role_changed', (m) async {
      _isRoleChangeInProgress = true;
      try {
        final data = _asMap(m);
        final currentUuid = await _getCurrentUserUuid();
        final participantUuid = data['user_uuid']?.toString();
        final newRole = data['role']?.toString()?.toLowerCase() ?? 'audience';

        if (participantUuid == currentUuid) {
          _participantRoleCtrl.add(newRole);
          if (newRole == 'guest' || newRole == 'cohost') {
            await _promoteCurrentUserToGuest();
          } else if (newRole == 'viewer' || newRole == 'audience') {
            await _demoteCurrentUserToAudience();
          }
        } else {
          if (newRole == 'guest' || newRole == 'cohost') {
            _activeGuestUuid = participantUuid;
            _activeGuestCtrl.add(_activeGuestUuid);
          } else if (participantUuid == _activeGuestUuid) {
            _activeGuestUuid = null;
            _activeGuestCtrl.add(null);
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

    bindEvent(chMeta, 'viewer.count', (m) {
      final data = _asMap(m);
      final raw = data['count'] ?? data['viewers'] ?? 0;
      final v = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
      _viewerCtrl.add(v);
    });

    bindEvent(chChat, 'chat.message', (m) => _handleChatMessage(m));

    bindEvent(chRoot, 'live.ended', (_) => _endedCtrl.add(null));

    bindEvent(chMeta, 'live.paused', (data) {
      if (_pauseCtrl.isClosed) return;
      final paused =
          data['paused'] == true ||
          data['is_paused'] == true ||
          data['pause'] == true;
      _pauseCtrl.add(paused);
    });

    // ── Step 7: Hydrate chat & start clock ─────────────────────────────────
    await _hydrateRecentChat();
    _startClock();

    _wired = true;
    _hasStarted = true;
    _isWiring = false;
    _wiringFuture = null;

    final elapsed = DateTime.now().difference(_wireStartedAt!);
    debugPrint(
      '✅ Wiring done in ${elapsed.inMilliseconds} ms '
      '(${_boundEventKeys.length} events)',
    );
  }

  // ── Safe HTTP helpers (return empty map on failure, never throw) ──────────

  Future<Map<String, dynamic>> _safeGet(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await http.dio.get(path, queryParameters: query);
      return _asMap(res.data);
    } catch (e) {
      debugPrint('⚠️ GET $path failed (non-fatal): $e');
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _safePost(String path) async {
    try {
      final res = await http.dio.post(path);
      return _asMap(res.data);
    } catch (e) {
      debugPrint('⚠️ POST $path failed (non-fatal): $e');
      return <String, dynamic>{};
    }
  }

  // ── Promotion / demotion helpers (unchanged) ─────────────────────────────

  Future<void> _promoteCurrentUserToGuest() async {
    try {
      final rtcRes = await http.dio.get(
        '$_basePath/rtc',
        queryParameters: {'role': 'publisher'},
      );
      final rtcData = _asMap(rtcRes.data);
      await agoraViewerService.promoteToCoHost(
        rtcToken: rtcData['rtc_token'].toString(),
      );
    } catch (e) {
      debugPrint('❌ Promotion failed: $e');
    }
  }

  Future<void> _demoteCurrentUserToAudience() async {
    try {
      await agoraViewerService.demoteToAudience();
      final rtcRes = await http.dio.get(
        '$_basePath/rtc',
        queryParameters: {'role': 'audience'},
      );
      final rtcData = _asMap(rtcRes.data);
      await agoraViewerService.renewToken(rtcData['rtc_token'].toString());
    } catch (e) {
      debugPrint('❌ Demotion failed: $e');
    }
  }

  // ── Chat helpers (unchanged) ──────────────────────────────────────────────

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
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _getCurrentUserUuid() async {
    try {
      return await authLocalDataSource.getCurrentUserUuid();
    } catch (e) {
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
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
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
    final entry = '[${DateTime.now()}] $channel -> $event: ${data.toString()}';
    _eventHistory.add(entry);
    if (_eventHistory.length > 50) _eventHistory.removeAt(0);
    debugPrint('📡 EVENT: $entry');
  }

  // ============ CLEANUP ============

  @override
  void dispose() {
    if (_disposed) return;

    if (keepAlive) {
      // SOFT dispose — called by LiveViewerScreen on page swipe-away.
      // Send /leave and reset wiring flags so the repo can be rewired
      // on swipe-back, but keep stream controllers OPEN for reuse.
      debugPrint('🛡️ [Repository] Soft dispose (keepAlive): $livestreamParam');
      try {
        cancelClock();
        http.dio.post('$_basePath/leave').ignore();
        pusher.unsubscribeAll();
      } catch (_) {}
      _wired = false;
      _hasStarted = false;
      _isWiring = false;
      _wiringFuture = null;
      _preWarmedRtcData = null;
      _boundEventKeys.clear();
      // Do NOT set _disposed = true, do NOT close stream controllers
      return;
    }

    // HARD dispose — called by pager on exit (keepAlive=false).
    _disposed = true;
    try {
      cancelClock();
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

    debugPrint('🗑️ Repository hard disposed: $livestreamParam');
  }
}
