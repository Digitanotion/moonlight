import 'dart:async';
import 'dart:convert';

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

  ViewerRepositoryImpl({
    required this.http,
    required this.pusher,
    required this.authLocalDataSource,
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
  final _activeGuestCtrl = StreamController<String?>.broadcast();
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

    // Auto-join as audience immediately
    try {
      // 1. First, call enter endpoint to update viewer count
      final enterRes = await http.dio.post('$_basePath/enter');
      final enterData = (enterRes.data is Map)
          ? (enterRes.data as Map)
          : jsonDecode(enterRes.data as String) as Map;
      final v = (enterData['viewers'] ?? 0) as int;
      _viewerCtrl.add(v);

      // 2. Auto-join as audience without waiting for approval
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

      // Notify that we've successfully joined as audience
      _myApprovalCtrl.add(true);
    } catch (e) {
      debugPrint('⚠️ Auto-join as audience failed: $e');
      _myApprovalCtrl.add(false);

      // Check if it's an API error (like being removed from stream)
      if (e is DioException) {
        final errorMessage = _extractErrorMessage(e);
        if (errorMessage.isNotEmpty) {
          // Broadcast the error message to the UI
          _errorCtrl.add(errorMessage);
        }
      }
    }

    final id = livestreamIdNumeric;
    final chMeta = 'live.$id.meta';
    final chChat = 'live.$id.chat';
    final chJoin = 'live.$id.join';
    final chRoot = 'live.$id';

    await pusher.subscribe(chMeta);
    await pusher.subscribe(chChat);
    await pusher.subscribe(chJoin);
    await pusher.subscribe(chRoot);

    // ========= PARTICIPANT EVENTS HANDLING =========
    pusher.bind(chMeta, 'participant.added', (m) async {
      debugPrint('participant.added: $m');
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

    pusher.bind(chMeta, 'participant.removed', (m) async {
      debugPrint('participant.removed: $m');
      final participantData = m is Map
          ? m.cast<String, dynamic>()
          : <String, dynamic>{};

      final currentUserUuid = await _getCurrentUserUuid();
      final participantUuid = participantData['user_uuid']?.toString();

      if (participantUuid == currentUserUuid) {
        final reason =
            participantData['reason']?.toString() ?? 'removed_by_host';
        debugPrint('🎯 Current user removed: $reason');

        _rtc.leave().ignore();
        _participantRemovedCtrl.add(reason);
        _errorCtrl.add(_getRemovalMessage(reason));
      }

      // If active guest was removed, clear it for everyone
      if (participantUuid != null && participantUuid == _activeGuestUuid) {
        _activeGuestUuid = null;
        _activeGuestCtrl.add(null);
      }
    });

    pusher.bind(chMeta, 'participant.role_changed', (m) async {
      debugPrint('participant.role_changed: $m');
      final participantData = m is Map
          ? m.cast<String, dynamic>()
          : <String, dynamic>{};

      final currentUserUuid = await _getCurrentUserUuid();
      final participantUuid = participantData['user_uuid']?.toString();

      if (participantUuid == currentUserUuid) {
        final newRole = participantData['role']?.toString() ?? 'audience';
        debugPrint('🎯 Current user role changed to: $newRole');

        // await _handleRoleChange(newRole);
        await _handleRoleChange(newRole);
        _participantRoleCtrl.add(newRole);
      }

      // Track global active guest for layout
      final role = (participantData['role']?.toString() ?? '').toLowerCase();
      if (role == 'guest' || role == 'cohost') {
        _activeGuestUuid = participantUuid;
        _activeGuestCtrl.add(_activeGuestUuid);
      } else if (participantUuid != null &&
          participantUuid == _activeGuestUuid) {
        _activeGuestUuid = null;
        _activeGuestCtrl.add(null);
      }
    });

    pusher.bind(chMeta, 'viewer.count', (m) {
      final raw = (m['count'] ?? m['viewers'] ?? 0);
      final v = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
      _viewerCtrl.add(v);
    });

    pusher.bind(chMeta, 'live.paused', (m) {
      final paused = (m['paused'] ?? false) == true;
      _pauseCtrl.add(paused);
    });

    void _ended(Map<String, dynamic> _) {
      _endedCtrl.add(null);
      _rtc.leave().ignore();
    }

    pusher.bind(chMeta, 'live.ended', _ended);
    pusher.bind(chRoot, 'live.ended', _ended);

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

    pusher.bind(chRoot, 'gift.sent', (m) {
      final from = '${m['from'] ?? 'Someone'}';
      final gift = '${m['gift'] ?? 'Gift'}';
      final coins = (m['coins'] is num)
          ? (m['coins'] as num).toInt()
          : (int.tryParse('${m['coins']}') ?? 0);
      _giftCtrl.add(GiftNotice(from: from, giftName: gift, coins: coins));
    });

    await _hydrateRecentChat();
    _startClock();
    _wired = true;
  }

  // Add these new stream controllers for error and participant events
  final _errorCtrl = StreamController<String>.broadcast();
  final _participantRoleCtrl = StreamController<String>.broadcast();
  final _participantRemovedCtrl = StreamController<String>.broadcast();

  // Add these new stream getters to the repository interface
  Stream<String> watchErrors() {
    _ensureWiredOnce();
    return _errorCtrl.stream;
  }

  Stream<String> watchParticipantRoleChanges() {
    _ensureWiredOnce();
    return _participantRoleCtrl.stream;
  }

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

  // Helper method to handle role changes
  Future<void> _handleRoleChange(String newRole) async {
    try {
      if (newRole == 'guest' || newRole == 'cohost') {
        // ✅ Correct path: promote-in-place to publisher
        final creds = await _fetchRtcCreds(role: 'publisher');
        await _rtc.promoteToCoHost(rtcToken: creds.token);
        // Rejoin with publisher role for guest/cohost
        // final creds = await _fetchRtcCreds(role: 'publisher');
        // await _rtc.leave();
        // await _rtc.joinAudience(
        //   appId: creds.appId,
        //   channel: creds.channel,
        //   uidType: creds.uidType,
        //   uid: creds.uid,
        //   rtcToken: creds.token,
        // );
      }
    } catch (e) {
      debugPrint('⚠️ Role change handling failed: $e');
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
    // await _ensureWiredOnce();
    // try {
    //   final res = await http.dio.post('$_basePath/join');
    //   final m = _asMap(res.data);

    //   // ✅ accept any shape and store as string
    //   final rid = m['id'] ?? m['request_id'];
    //   _myJoinRequestId = rid == null ? null : '$rid';

    //   if (kDebugMode) debugPrint('▶️ join request id=$_myJoinRequestId');
    // } on DioException catch (e) {
    //   final m = _asMap(e.response?.data);
    //   final msg = '${m['message'] ?? ''}'.toLowerCase();
    //   final rid = m['id'] ?? m['request_id'];

    //   // ✅ handle idempotent “already pending”
    //   if (e.response?.statusCode == 200 || msg.contains('already')) {
    //     if (rid != null) _myJoinRequestId = '$rid';
    //     return;
    //   }
    //   rethrow;
    // }
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
    _activeGuestCtrl.close();
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

      // Check for API errors in response
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
      // Propagate the error with proper message
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
