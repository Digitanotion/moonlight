import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/core/services/agora_service.dart';
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

  @override
  void setLocalPause(bool paused) {
    _locallyPaused = paused;
    _agora.setMicEnabled(!paused);
    _agora.setCameraEnabled(!paused);
  }

  @override
  Future<void> startSession({required String topic}) async {
    final s = _tracker.current;
    // NEW: only drop previous live.* channels for *this* livestream id
    try {
      await _pusher.unsubscribePrefix('live.${_tracker.current!.livestreamId}');
    } catch (_) {}
    // (connect() is called automatically inside subscribe(); no need here)
    if (s == null) throw StateError('No active LiveStartPayload found.');

    // 1) Host goes live on Agora
    await _agora.startPublishing(
      appId: s.appId,
      channel: s.channel,
      token: s.rtcToken,
      uidType: s.uidType,
      uid: s.uid,
    );

    // 2) Listen to sockets (resilient to event-name variants)
    try {
      final meta = 'live.${s.livestreamId}.meta';
      final chat = 'live.${s.livestreamId}.chat';
      final join = 'live.${s.livestreamId}.join';
      final root = 'live.${s.livestreamId}';
      final viewer = 'live.${s.livestreamId}.viewer';
      final guest =
          'live.${s.livestreamId}.guest'; // guestbox (if back-end uses it)

      await _pusher.subscribe(meta);
      debugPrint('subscribed live.${s.livestreamId}.meta');
      await _pusher.subscribe(chat);
      debugPrint('subscribed live.${s.livestreamId}.chat');
      await _pusher.subscribe(join);
      debugPrint('subscribed live.${s.livestreamId}.join');
      await _pusher.subscribe(root);
      debugPrint('subscribed live.${s.livestreamId}');
      await _pusher.subscribe(guest);
      await _pusher.subscribe(viewer);
      debugPrint('subscribed live.${s.livestreamId}.viewer');

      // helpers
      Map<String, dynamic> _normalize(dynamic raw) {
        Map<String, dynamic> m = (raw is Map<String, dynamic>)
            ? raw
            : <String, dynamic>{};
        if (m['payload'] is Map)
          m = (m['payload'] as Map).cast<String, dynamic>();
        if (m['data'] is Map) m = (m['data'] as Map).cast<String, dynamic>();
        return m;
      }

      void _bindAny(
        String channel,
        List<String> events,
        void Function(Map<String, dynamic>) cb,
      ) {
        for (final e in events) {
          _pusher.bind(channel, e, (raw) => cb(_normalize(raw)));
        }
      }

      // Remove the complex _bindAny call and replace with:

      // 1) Direct binding like viewer repository
      _pusher.bind(viewer, 'viewer.count', (raw) {
        final m = _asMap(raw);
        final rawCount = (m['count'] ?? m['viewers'] ?? 0);
        final count = rawCount is num
            ? rawCount.toInt()
            : int.tryParse('$rawCount') ?? 0;
        debugPrint('🎯 HOST: Viewer count updated to $count');
        _viewersCtrl.add(count);
      });

      // 2) Also bind to main channel as backup (like viewer repo does for live.ended)
      _pusher.bind('live.${s.livestreamId}', 'viewer.count', (raw) {
        final m = _asMap(raw);
        final rawCount = (m['count'] ?? m['viewers'] ?? 0);
        final count = rawCount is num
            ? rawCount.toInt()
            : int.tryParse('$rawCount') ?? 0;
        debugPrint('🎯 HOST (main channel): Viewer count updated to $count');
        _viewersCtrl.add(count);
      });

      // live.paused
      _bindAny(meta, ['live.paused', 'App\\Events\\LivePaused'], (m) {
        final p = m['paused'];
        final paused = p == true || p == 'true' || p == 1;
        _pauseCtrl.add(paused);
        setLocalPause(paused);
      });

      // Live ended
      _pusher.bind(root, 'live.ended', (raw) {
        debugPrint('🎯 Live ended event received');
        _endedCtrl.add(null);
      });

      // chat.message
      // _bindAny(chat, ['chat.message', 'App\\Events\\ChatMessage'], (m) {
      //   final body = (m['chat'] is Map)
      //       ? (m['chat'] as Map).cast<String, dynamic>()
      //       : m;
      //   final text = (body['text'] ?? '').toString();

      //   String handle;
      //   if (body['user'] is Map) {
      //     final u = (body['user'] as Map).cast<String, dynamic>();
      //     handle = '@${(u['user_slug'] ?? u['slug'] ?? 'user')}';
      //   } else {
      //     handle = '@${(body['user'] ?? 'user').toString()}';
      //   }
      //   _chatCtrl.add(LiveChatMessage(handle, text));
      // });

      // Chat message
      _pusher.bind(chat, 'chat.message', (raw) {
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
      });
      // gifts
      _bindAny(root, ['gift.sent', 'App\\Events\\GiftSent'], (m) {
        final from = (m['from'] ?? 'Someone').toString();
        final gift = (m['gift'] ?? 'Gift').toString();
        final coins = (m['coins'] is int)
            ? m['coins'] as int
            : int.tryParse('${m['coins']}') ?? 0;
        _giftsCtrl.add(
          GiftEvent(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            from: from,
            giftName: gift,
            coins: coins,
          ),
        );
      });

      // join requests (viewer → host)
      void _emitJoinReq(Map<String, dynamic> m) {
        final id = (m['id'] ?? m['request_id'] ?? '').toString();
        final user = (m['user'] as Map?)?.cast<String, dynamic>() ?? const {};
        final slug = (user['user_slug'] ?? user['slug'] ?? 'guest').toString();
        final avatar = (user['avatar'] ?? '').toString();
        final display = (user['display_name'] ?? slug).toString();
        if (id.isEmpty) return;
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

      _bindAny(join, [
        // custom + FQN variants
        'join.requested',
        'join.created',
        'App\\Events\\JoinRequested',
        'App\\Events\\JoinCreated',
      ], _emitJoinReq);

      // some backends also mirror request/decision on the root/guest channels:
      _bindAny(root, ['GuestBoxRequested'], _emitJoinReq);
      _bindAny(guest, [
        'guest.requested',
        'App\\Events\\GuestRequested',
      ], _emitJoinReq);

      // join handled (accept/decline) — multiple names
      void _emitHandled(Map<String, dynamic> m, {bool? acceptedOverride}) {
        final id = (m['id'] ?? m['request_id'] ?? '').toString();
        final accepted =
            acceptedOverride ??
            (m['accepted'] == true) ||
                (m['status']?.toString().toLowerCase() == 'accepted');
        if (id.isEmpty) return;
        _joinHandledCtrl.add(JoinHandled(id, accepted));
      }

      _bindAny(join, ['join.handled', 'App\\Events\\JoinHandled'], (m) {
        _emitHandled(m);
      });

      // explicit accept/decline events some apps emit
      _bindAny(join, [
        'join.accepted',
      ], (m) => _emitHandled(m, acceptedOverride: true));
      _bindAny(join, [
        'join.declined',
      ], (m) => _emitHandled(m, acceptedOverride: false));

      // guestbox decision variants (if guest channel is used)
      _bindAny(root, ['GuestBoxDecision'], (m) {
        _emitHandled(m);
      });
      _bindAny(guest, ['guest.decision', 'App\\Events\\GuestDecision'], (m) {
        _emitHandled(m);
      });
    } catch (_) {
      // sockets should never crash the host session
    }
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
    // Also drop any lingering channel bindings (safe even if none)
    // If you share PusherService elsewhere, this only affects the live.* channels we created.
    // We already call unsubscribeAll() at startSession; this is a “belt & suspenders” cleanup.
    try {
      _pusher.unsubscribeAll();
    } catch (_) {}
  }
}
