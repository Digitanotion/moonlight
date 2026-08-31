// lib/features/video_call/data/repositories/video_call_repository_impl.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' show debugPrint;
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/video_call/data/models/video_call_session_model.dart';
import 'package:moonlight/features/video_call/domain/repositories/video_call_repository.dart';

class VideoCallRepositoryImpl implements VideoCallRepository {
  final DioClient _client;
  final PusherService _pusher;

  String myUserUuid;

  VideoCallRepositoryImpl(
    this._client,
    this._pusher, {
    required this.myUserUuid,
  });

  final _incomingCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _acceptedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _resolvedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _pauseStateCtrl = StreamController<Map<String, dynamic>>.broadcast();

  bool _subscribed = false;
  String? _subscribedChannel;
  final List<void Function(Map<String, dynamic>)> _boundHandlers = [];

  @override
  Stream<Map<String, dynamic>> incomingCallStream() => _incomingCtrl.stream;

  @override
  Stream<Map<String, dynamic>> callAcceptedStream() => _acceptedCtrl.stream;

  /// Fires when the OTHER party ends or rejects a call currently in
  /// progress on this device — payload includes 'type' (video_call_ended
  /// or video_call_rejected) and meta.session_uuid so the listener can
  /// confirm it's for the call currently on screen. Without this, a
  /// caller/callee's screen never finds out the other side hung up.
  Stream<Map<String, dynamic>> callResolvedStream() => _resolvedCtrl.stream;

  @override
  Stream<Map<String, dynamic>> callPauseStateStream() => _pauseStateCtrl.stream;

  @override
  void injectExternalEvent(Map<String, dynamic> payload) {
    // FCM data messages are always flat strings, with no nested 'meta'
    // map — normalize to the shape every downstream listener (built for
    // the Pusher handler below) already expects, so this is a drop-in
    // second source rather than something every listener needs its own
    // special-case for.
    final normalized = payload.containsKey('meta')
        ? payload
        : <String, dynamic>{...payload, 'meta': payload};
    _routeEvent(normalized);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  @override
  void subscribeToCallEvents() {
    if (_subscribed) return;
    _doSubscribe();
  }

  @override
  void resubscribeForUser(String userUuid) {
    if (userUuid.isEmpty || userUuid == myUserUuid) {
      if (!_subscribed && userUuid.isNotEmpty) {
        myUserUuid = userUuid;
        _doSubscribe();
      }
      return;
    }

    debugPrint('📞 [VideoCall] Re-subscribing: $myUserUuid -> $userUuid');
    _teardownSubscription();
    myUserUuid = userUuid;
    _doSubscribe();
  }

  void _doSubscribe() {
    if (myUserUuid.isEmpty) {
      debugPrint('⚠️ [VideoCall] Cannot subscribe — no user uuid yet');
      return;
    }

    final channel = 'private-users.$myUserUuid.notifications';
    _subscribedChannel = channel;
    _subscribed = true;

    _pusher.subscribePrivate(channel);

    void handler(Map<String, dynamic> raw) => _routeEvent(_asMap(raw));

    _pusher.bind(channel, 'notification.received', handler);
    _boundHandlers.add(handler);
  }

  /// Single dispatch point for a video-call notification payload,
  /// regardless of whether it arrived via the live Pusher socket (above)
  /// or was injected from FCM's foreground listener (injectExternalEvent).
  void _routeEvent(Map<String, dynamic> payload) {
    final type = (payload['type'] ?? '').toString();

    switch (type) {
      case 'video_call_incoming':
        debugPrint('📞 [VideoCall] Incoming call notification');
        _incomingCtrl.add(payload);
        break;
      case 'video_call_accepted':
        debugPrint('📞 [VideoCall] Call accepted notification');
        _acceptedCtrl.add(payload);
        break;
      case 'video_call_ended':
      case 'video_call_rejected':
        debugPrint('📞 [VideoCall] Call resolved by other party: $type');
        _resolvedCtrl.add(payload);
        break;
      case 'video_call_paused':
      case 'video_call_resumed':
        debugPrint('📞 [VideoCall] Call pause state changed: $type');
        _pauseStateCtrl.add(payload);
        break;
      default:
        break;
    }
  }

  void _teardownSubscription() {
    final channel = _subscribedChannel;
    if (channel == null) return;
    for (final handler in _boundHandlers) {
      try {
        _pusher.unbind(channel, 'notification.received', handler);
      } catch (_) {}
    }
    _boundHandlers.clear();
    try {
      _pusher.unsubscribe(channel);
    } catch (_) {}
    _subscribed = false;
    _subscribedChannel = null;
  }

  @override
  Future<List<VideoCallDirectoryUserModel>> fetchDirectory({
    String? country,
    String? username,
    int page = 1,
  }) async {
    final res = await _client.dio.get(
      '/api/v1/video-call/directory',
      queryParameters: {
        if (country != null && country.isNotEmpty) 'country': country,
        if (username != null && username.isNotEmpty) 'username': username,
        'page': page,
      },
    );
    final map = _asMap(res.data);
    final data = _asMap(map['data']);
    final list = (data['data'] as List?) ?? [];
    return list
        .map((e) => VideoCallDirectoryUserModel.fromMap(_asMap(e)))
        .toList();
  }

  VideoCallSessionModel _sessionFromResponse(dynamic responseData) {
    final map = _asMap(responseData);
    return VideoCallSessionModel.fromMap(_asMap(map['data']));
  }

  @override
  Future<VideoCallSessionModel> initiate({
    required String calleeUserSlug,
    required int minutes,
    required String initiatedFrom,
    int? livestreamId,
    String? idempotencyKey,
  }) async {
    final res = await _client.dio.post(
      '/api/v1/video-call/initiate',
      data: {
        'callee_user_slug': calleeUserSlug,
        'minutes': minutes,
        'initiated_from': initiatedFrom,
        if (livestreamId != null) 'livestream_id': livestreamId,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
    );
    return _sessionFromResponse(res.data);
  }

  @override
  Future<VideoCallSessionModel> accept(String sessionUuid) async {
    final res = await _client.dio.post(
      '/api/v1/video-call/$sessionUuid/accept',
    );
    return _sessionFromResponse(res.data);
  }

  @override
  Future<VideoCallSessionModel> join(String sessionUuid) async {
    final res = await _client.dio.post('/api/v1/video-call/$sessionUuid/join');
    return _sessionFromResponse(res.data);
  }

  @override
  Future<VideoCallSessionModel> reject(String sessionUuid) async {
    final res = await _client.dio.post(
      '/api/v1/video-call/$sessionUuid/reject',
    );
    return _sessionFromResponse(res.data);
  }

  @override
  Future<VideoCallSessionModel> extend({
    required String sessionUuid,
    required int minutes,
    String? idempotencyKey,
  }) async {
    final res = await _client.dio.post(
      '/api/v1/video-call/$sessionUuid/extend',
      data: {
        'minutes': minutes,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
    );
    final map = _asMap(res.data);
    final data = _asMap(map['data']);
    return VideoCallSessionModel.fromMap(_asMap(data['session']));
  }

  @override
  Future<VideoCallSessionModel> end({
    required String sessionUuid,
    String? reason,
  }) async {
    final res = await _client.dio.post(
      '/api/v1/video-call/$sessionUuid/end',
      data: {if (reason != null) 'reason': reason},
    );
    return _sessionFromResponse(res.data);
  }

  @override
  Future<VideoCallSessionModel> status(String sessionUuid) async {
    final res = await _client.dio.get('/api/v1/video-call/$sessionUuid/status');
    return _sessionFromResponse(res.data);
  }

  @override
  Future<VideoCallSessionModel> pause(String sessionUuid) async {
    final res = await _client.dio.post('/api/v1/video-call/$sessionUuid/pause');
    return _sessionFromResponse(res.data);
  }

  @override
  Future<VideoCallSessionModel> resume(String sessionUuid) async {
    final res = await _client.dio.post('/api/v1/video-call/$sessionUuid/resume');
    return _sessionFromResponse(res.data);
  }

  @override
  Future<void> report({
    required String sessionUuid,
    required String reason,
    String? note,
  }) async {
    await _client.dio.post(
      '/api/v1/video-call/$sessionUuid/report',
      data: {'reason': reason, if (note != null) 'note': note},
    );
  }

  @override
  Future<void> toggleOnline(bool online) async {
    await _client.dio.post(
      '/api/v1/video-call/online',
      data: {'online': online},
    );
  }

  @override
  Future<void> toggleEnabled(bool enabled) async {
    await _client.dio.post(
      '/api/v1/video-call/enabled',
      data: {'enabled': enabled},
    );
  }

  @override
  Future<void> broadcast({
    required String audience,
    String? message,
    String? idempotencyKey,
  }) async {
    await _client.dio.post(
      '/api/v1/video-call/broadcast',
      data: {
        'audience': audience,
        if (message != null) 'message': message,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
    );
  }

  @override
  Future<void> boost(String duration) async {
    await _client.dio.post(
      '/api/v1/video-call/boost',
      data: {'duration': duration},
    );
  }

  @override
  void dispose() {
    _teardownSubscription();
  }
}
