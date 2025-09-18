import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';

import '../../domain/entities.dart';
import '../../domain/repositories/viewer_repository.dart';
import '../../domain/video_surface_provider.dart';

class ViewerRepositoryImpl implements ViewerRepository, VideoSurfaceProvider {
  final DioClient http;
  final PusherService pusher;

  /// REST path segment: UUID or numeric (both accepted by backend)
  final String livestreamParam;

  /// Pusher channel id: MUST be numeric
  final int livestreamIdNumeric;

  /// Agora channel name (e.g., "live_ABC...")
  final String channelName;

  final HostInfo? initialHost;
  final DateTime? startedAt;

  ViewerRepositoryImpl({
    required this.http,
    required this.pusher,
    required this.livestreamParam,
    required this.livestreamIdNumeric,
    required this.channelName,
    this.initialHost,
    this.startedAt,
  }) : _rtc = AgoraViewerService(
         onTokenRefresh: (_) async {
           // Audience tokens might refresh; ask server for the correct role
           final token = await _fetchRtcTokenStatic(
             http: http,
             livestreamParam: livestreamParam,
             role: "audience", // 'audience' | 'publisher'
           );
           return token;
         },
       );

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

  Timer? _clockTimer;
  Future<void>? _wiringFuture;
  bool _wired = false;

  String? _myJoinRequestId;

  String get _basePath => '/api/v1/live/$livestreamParam';

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

    // Optionally let backend count the viewer; ignore errors (idempotent server-side)
    try {
      final res = await http.dio.post('$_basePath/enter');
      final data = (res.data is Map)
          ? (res.data as Map)
          : jsonDecode(res.data as String) as Map;
      final v = (data['viewers'] ?? 0) as int;
      _viewerCtrl.add(v);
    } catch (_) {}

    final id = livestreamIdNumeric;
    final chMeta = 'live.$id.meta';
    final chChat = 'live.$id.chat';
    final chJoin = 'live.$id.join';
    final chRoot = 'live.$id';

    await pusher.subscribe(chMeta);
    await pusher.subscribe(chChat);
    await pusher.subscribe(chJoin);
    await pusher.subscribe(chRoot);

    // viewer.count
    pusher.bind(chMeta, 'viewer.count', (m) {
      final raw = (m['count'] ?? m['viewers'] ?? 0);
      final v = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
      _viewerCtrl.add(v);
    });

    // live.paused
    pusher.bind(chMeta, 'live.paused', (m) {
      final paused = (m['paused'] ?? false) == true;
      _pauseCtrl.add(paused);
    });

    // live.ended (some backends send here too)
    void _ended(Map<String, dynamic> _) {
      _endedCtrl.add(null);
      _rtc.leave().ignore();
    }

    pusher.bind(chMeta, 'live.ended', _ended);
    pusher.bind(chRoot, 'live.ended', _ended);

    // chat.message
    pusher.bind(chChat, 'chat.message', (m) {
      final Map<String, dynamic> obj = (m['chat'] is Map)
          ? (m['chat'] as Map).cast<String, dynamic>()
          : (m as Map<String, dynamic>);
      _chatCtrl.add(
        ChatMessage(
          id: '${obj['id']}',
          username: obj['user'] is Map
              ? '${(obj['user'] as Map)['user_slug'] ?? (obj['user'] as Map)['name'] ?? 'user'}'
              : '${obj['user']}',
          text: '${obj['text']}',
        ),
      );
    });

    // join flow (view-only gate)
    // join.created often broadcasts who requested (for banners, optional)
    final Map<String, String> joinUserById = {};
    pusher.bind(chJoin, 'join.created', (m) {
      final rid = '${m['id'] ?? ''}';
      final u = (m['user'] ?? const {}) as Map<String, dynamic>;
      joinUserById[rid] = '${u['slug'] ?? u['user_slug'] ?? 'viewer'}';
    });

    // join.accepted / join.declined → decision for a specific join request
    Future<void> _handleJoinDecision(
      Map<String, dynamic> m, {
      required bool accepted,
    }) async {
      final ridFromEvent = '${m['id'] ?? m['request_id'] ?? ''}';

      // ✅ string-to-string compare (e.g., "jr_01K5F5...")
      if (_myJoinRequestId != null && ridFromEvent == _myJoinRequestId) {
        if (accepted) {
          try {
            final creds = await _fetchRtcCreds(role: 'audience');
            debugPrint(
              '[RTC] audience creds: appId=${creds.appId}, ch=${creds.channel}, '
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
            debugPrint('⚠️ audience join failed: $e');
            _myApprovalCtrl.add(false);
          }
        } else {
          _myApprovalCtrl.add(false);
        }
      } else {
        // (Optional) log unmatched decisions for debugging
        if (kDebugMode) {
          debugPrint(
            'ℹ️ join decision for $ridFromEvent did not match my $_myJoinRequestId',
          );
        }
      }
    }

    // Bind both decision events
    pusher.bind(chJoin, 'join.accepted', (m) async {
      await _handleJoinDecision(
        (m is Map) ? m.cast<String, dynamic>() : <String, dynamic>{},
        accepted: true,
      );
    });

    pusher.bind(chJoin, 'join.declined', (m) async {
      await _handleJoinDecision(
        (m is Map) ? m.cast<String, dynamic>() : <String, dynamic>{},
        accepted: false,
      );
    });

    // gifts
    pusher.bind(chRoot, 'gift.sent', (m) {
      final from = '${m['from'] ?? 'Someone'}';
      final gift = '${m['gift'] ?? 'Gift'}';
      final coins = (m['coins'] is num)
          ? (m['coins'] as num).toInt()
          : (int.tryParse('${m['coins']}') ?? 0);
      _giftCtrl.add(GiftNotice(from: from, giftName: gift, coins: coins));
    });

    // hydrate chat (best-effort)
    await _hydrateRecentChat();

    // live clock
    _startClock();

    _wired = true;
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

  void _startClock() {
    _clockTimer?.cancel();
    final base = startedAt ?? DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _clockCtrl.add(DateTime.now().difference(base));
    });
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
      // message arrives via pusher
    } catch (e) {
      debugPrint('⚠️ sendComment failed: $e');
    }
  }

  @override
  Future<int> like() async => 0;

  @override
  Future<int> share() async => 0;

  /// Viewer join (view-only). We listen for join.handled to be accepted/declined.
  @override
  Future<void> requestToJoin() async {
    await _ensureWiredOnce();
    try {
      final res = await http.dio.post('$_basePath/join');
      final m = _asMap(res.data);

      // ✅ accept any shape and store as string
      final rid = m['id'] ?? m['request_id'];
      _myJoinRequestId = rid == null ? null : '$rid';

      if (kDebugMode) debugPrint('▶️ join request id=$_myJoinRequestId');
    } on DioException catch (e) {
      final m = _asMap(e.response?.data);
      final msg = '${m['message'] ?? ''}'.toLowerCase();
      final rid = m['id'] ?? m['request_id'];

      // ✅ handle idempotent “already pending”
      if (e.response?.statusCode == 200 || msg.contains('already')) {
        if (rid != null) _myJoinRequestId = '$rid';
        return;
      }
      rethrow;
    }
  }

  @override
  Future<bool> toggleFollow(bool follow) async => !follow;

  // ========= Cleanup =========
  @override
  void dispose() {
    try {
      _clockTimer?.cancel();
      http.dio.post('$_basePath/leave').ignore(); // idempotent server side
      pusher.unsubscribeAll();
    } catch (_) {}

    _clockCtrl.close();
    _viewerCtrl.close();
    _chatCtrl.close();
    _guestCtrl.close();
    _giftCtrl.close();
    _pauseCtrl.close();
    _endedCtrl.close();
    _myApprovalCtrl.close();

    _rtc.leave().ignore();
    _rtc.disposeEngine().ignore();
  }

  // ========= RTC creds helpers =========
  Future<_RtcCreds> _fetchRtcCreds({required String role}) async {
    final res = await http.dio.get(
      '$_basePath/rtc',
      queryParameters: {'role': role}, // 'audience' for view-only
    );
    final m = _asMap(res.data);
    return _RtcCreds(
      appId: '${m['agora']?['app_id'] ?? m['app_id']}',
      token: '${m['agora']?['rtc_token'] ?? m['rtc_token']}',
      uidType: '${m['uid_type'] ?? 'uid'}',
      uid: '${m['rtc_uid']}',
      channel: '${m['channel'] ?? channelName}',
    );
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

  // ========= VideoSurfaceProvider =========
  @override
  Widget buildHostVideo() => _rtc.hostVideoView();

  @override
  Widget? buildLocalPreview() => _rtc.localPreviewBubble();
}

class _RtcCreds {
  final String appId;
  final String token;
  final String uidType; // 'uid' | 'userAccount'
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
