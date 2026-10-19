// lib/features/clubs/rooms/club_room_controller.dart
//
// One open club room: server state + Pusher events + Agora + comments.
// The screen only renders this and calls its actions.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart'
    show GiftItem;
import 'package:uuid/uuid.dart';

import 'club_room_api.dart';
import 'club_room_models.dart';
import 'club_room_rtc.dart';

class GiftNotice {
  final String from;
  final String to; // "everyone" or a name
  final String giftCode;
  final String giftTitle;
  final String? imageUrl;
  final int quantity;
  final DateTime at = DateTime.now();
  GiftNotice(
    this.from,
    this.to,
    this.giftCode,
    this.giftTitle,
    this.imageUrl,
    this.quantity,
  );
}

class ClubRoomController with ChangeNotifier {
  ClubRoomController(this.roomUuid, {ClubRoomApi? api})
    : api = api ?? ClubRoomApi();

  final String roomUuid;
  final ClubRoomApi api;
  final ClubRoomRtc rtc = ClubRoomRtc();

  RoomState? state;
  final List<RoomComment> comments = [];
  final List<GiftNotice> gifts = [];
  List<GiftItem>? giftCatalog;

  bool ended = false;
  bool removed = false;
  bool busy = false;
  String? error;

  String get _channel => 'private-club-room.$roomUuid';
  String? get myUuid => sl<CurrentUserService>().getCurrentUserId();

  Timer? _refreshDebounce;
  bool _disposed = false;
  final Map<String, PusherCallback> _handlers = {};

  // ── lifecycle ─────────────────────────────────────────────────────────

  /// Loads the room without joining (so the screen can show fees first).
  Future<RoomState> load() async {
    final s = await api.state(roomUuid);
    state = s;
    ended = !s.isLive;
    removed = s.me.removed;
    _notify();
    return s;
  }

  /// Join (pays any audio entry fee server-side), then connect media,
  /// realtime and comments. Throws the API error (e.g. 402) to the caller.
  Future<void> enter() async {
    final s = state?.me.inRoom == true ? state! : await api.join(roomUuid);
    state = s;
    _notify();
    await _subscribe();
    await _connectRtc();
    unawaited(_loadComments());
    _applyPremium();
  }

  Future<void> leave() async {
    try {
      await api.leave(roomUuid);
    } catch (_) {}
    await _teardown();
  }

  Future<void> end() async {
    await api.end(roomUuid);
    ended = true;
    await _teardown();
  }

  Future<void> _teardown() async {
    _refreshDebounce?.cancel();
    await rtc.leave();
    _unsubscribe();
    _notify();
  }

  // ── actions ───────────────────────────────────────────────────────────

  Future<void> toggleMic() async {
    final muted = !rtc.micMuted;
    await rtc.setMicMuted(muted);
    try {
      _apply(await api.setMic(roomUuid, muted));
    } catch (_) {}
  }

  Future<void> requestSeat() async => _apply(await api.requestSeat(roomUuid));
  Future<void> cancelSeat() async => _apply(await api.cancelSeat(roomUuid));

  Future<void> decideSeat(String userUuid, bool approve) async =>
      _apply(await api.decideSeat(roomUuid, userUuid, approve: approve));

  Future<void> bringDown(String userUuid, {bool kick = false}) async =>
      _apply(await api.bringDown(roomUuid, userUuid, kick: kick));

  Future<void> setPremium(bool enabled, {int? price, String? mode}) async =>
      _apply(
        await api.setPremium(
          roomUuid,
          enabled: enabled,
          priceCoins: price,
          mode: mode ?? 'host_only',
        ),
      );

  Future<void> payPremium() async => _apply(await api.payPremium(roomUuid));

  Future<List<GiftItem>> loadGifts() async =>
      giftCatalog ??= await api.giftCatalog();

  Future<void> sendGift(GiftItem gift, String to, {int quantity = 1}) =>
      api.gift(
        roomUuid,
        giftCode: gift.code,
        to: to,
        quantity: quantity,
        idempotencyKey: const Uuid().v4(),
      );

  Future<void> postComment({String? body, String? replyTo, File? media}) async {
    final c = await api.postComment(
      roomUuid,
      body: body,
      replyTo: replyTo,
      media: media,
    );
    _upsertComment(c);
  }

  Future<void> editComment(String uuid, String body) async =>
      _upsertComment(await api.editComment(roomUuid, uuid, body));

  Future<void> deleteComment(String uuid) async {
    await api.deleteComment(roomUuid, uuid);
    comments.removeWhere((c) => c.uuid == uuid);
    _notify();
  }

  Future<void> refresh() async {
    try {
      _apply(await api.state(roomUuid));
    } catch (_) {}
  }

  // ── internals ─────────────────────────────────────────────────────────

  void _apply(RoomState s) {
    state = s;
    if (!s.isLive) ended = true;
    if (s.me.removed) removed = true;
    _notify();
    if (ended || removed) {
      _teardown();
      return;
    }
    // Promoted to camera / brought down → reconnect with the right role.
    if (s.me.inRoom && s.me.onStage != rtc.isPublisher && !_connecting) {
      _connectRtc();
    }
    _applyPremium();
  }

  void _applyPremium() {
    final s = state;
    if (s == null || s.isAudio) return;
    final hidden = s.participants
        .where((p) => !p.videoVisible && p.user.uuid != myUuid)
        .map((p) => p.user.uid)
        .toSet();
    rtc.setHiddenVideo(hidden);
  }

  bool _connecting = false;

  Future<void> _connectRtc() async {
    final s = state;
    if (s == null || !s.me.inRoom || _connecting) return;
    _connecting = true;
    error = null;
    try {
      final creds = await api.token(roomUuid);
      await rtc.join(creds, video: !s.isAudio, startMuted: s.me.micMuted);
      _applyPremium();
    } catch (e) {
      error = 'Could not connect audio/video. Pull to retry.';
      if (kDebugMode) debugPrint('[ClubRoom] rtc connect failed: $e');
      _notify();
    } finally {
      _connecting = false;
    }
  }

  /// Retry media after a failure.
  Future<void> reconnect() => _connectRtc();

  Future<void> _loadComments() async {
    try {
      final list = await api.comments(roomUuid);
      comments
        ..clear()
        ..addAll(list);
      _notify();
    } catch (_) {}
  }

  void _upsertComment(RoomComment c) {
    final i = comments.indexWhere((x) => x.uuid == c.uuid);
    if (i >= 0) {
      comments[i] = c;
    } else {
      comments.add(c);
    }
    _notify();
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), refresh);
  }

  Future<void> _subscribe() async {
    final pusher = sl<PusherService>();
    void on(String event, PusherCallback cb) {
      _handlers[event] = cb;
      pusher.bind(_channel, event, cb);
    }

    for (final e in const [
      'participants.changed',
      'seat.requested',
      'seat.approved',
      'seat.declined',
      'premium.changed',
      'participant.brought_down',
    ]) {
      on(e, (_) => _scheduleRefresh());
    }
    on('participant.removed', (p) {
      if (p['user_uuid'] == myUuid) {
        removed = true;
        _teardown();
      } else {
        _scheduleRefresh();
      }
    });
    on('room.ended', (_) {
      ended = true;
      _teardown();
    });
    on('comment.created', (p) => _upsertComment(RoomComment.fromJson(p)));
    on('comment.updated', (p) => _upsertComment(RoomComment.fromJson(p)));
    on('comment.deleted', (p) {
      comments.removeWhere((c) => c.uuid == p['uuid']);
      _notify();
    });
    on('gift.sent', (p) {
      final from = (p['from'] as Map?)?['display']?.toString() ?? 'Someone';
      final toList = (p['to'] as List?) ?? const [];
      final to = p['to_all'] == true
          ? 'everyone'
          : toList.map((t) => (t as Map)['display']).join(', ');
      final gift = (p['gift'] as Map?) ?? const {};
      gifts.add(
        GiftNotice(
          from,
          to,
          gift['code']?.toString() ?? '',
          gift['title']?.toString() ?? 'a gift',
          gift['image_url']?.toString(),
          (p['quantity'] as num?)?.toInt() ?? 1,
        ),
      );
      if (gifts.length > 20) gifts.removeAt(0);
      _notify();
      // The ticker shows a notice for 6s; redraw once it has expired.
      Timer(const Duration(milliseconds: 6100), _notify);
    });

    try {
      await pusher.subscribePrivate('club-room.$roomUuid');
    } catch (e) {
      if (kDebugMode) debugPrint('[ClubRoom] pusher subscribe failed: $e');
    }
  }

  void _unsubscribe() {
    final pusher = sl<PusherService>();
    _handlers.forEach((event, cb) => pusher.unbind(_channel, event, cb));
    _handlers.clear();
    try {
      pusher.unsubscribe(_channel);
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshDebounce?.cancel();
    _unsubscribe();
    rtc.dispose();
    super.dispose();
  }
}
