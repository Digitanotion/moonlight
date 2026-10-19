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
import 'room_background.dart';

class GiftNotice {
  final String from;
  final String to; // "everyone" or a name
  final String giftCode;
  final String giftTitle;
  final String? imageUrl;
  final int quantity;
  final DateTime at = DateTime.now();

  /// Arrival order in the room chat (shared with comments).
  int seq = 0;
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

  // Comments and gift notices share one chat, in the order they arrived —
  // gifts stay in the chat like on the main livestream screen.
  int _seq = 0;
  final Map<String, int> _commentSeq = {};

  /// Comments and gifts, oldest first. Items are [RoomComment] or
  /// [GiftNotice].
  List<Object> get chat {
    final items = <(int, Object)>[
      for (final c in comments) (_commentSeq[c.uuid] ?? 0, c),
      for (final g in gifts) (g.seq, g),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final i in items) i.$2];
  }

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
  /// True once [enter] has connected — the room is running (even while
  /// its screen is closed / minimised).
  bool entered = false;

  /// Still in the call (not left, ended or removed).
  bool get active => entered && !ended && !removed && !_left;
  bool _left = false;
  bool get hasLeft => _left;

  Future<void> enter() async {
    final s = state?.me.inRoom == true ? state! : await api.join(roomUuid);
    state = s;
    _notify();
    await _subscribe();
    await _connectRtc();
    unawaited(_loadComments());
    _applyPremium();
    // Backup for missed realtime messages: re-sync the room every 15s so
    // mic states, seats and people never stay stale for long.
    entered = true;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!ended && !removed) refresh();
    });
  }

  Timer? _poll;

  Future<void> leave() async {
    _left = true;
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
    _poll?.cancel();
    unawaited(RoomBackground.stop());
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
    rtc.setWatchVideo(s.canWatchVideo);
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
      // Keep the room going while the user is in other apps.
      unawaited(
        RoomBackground.start(
          title: (s.title ?? '').trim().isNotEmpty
              ? s.title!.trim()
              : s.clubName,
          video: !s.isAudio,
          mic: s.me.onStage,
        ),
      );
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
      // History sorts before anything that arrived live while loading.
      final liveOnly = comments
          .where((c) => !list.any((x) => x.uuid == c.uuid))
          .toList();
      comments
        ..clear()
        ..addAll(list)
        ..addAll(liveOnly);
      var i = -list.length - 1;
      for (final c in list) {
        _commentSeq.putIfAbsent(c.uuid, () => i++);
      }
      _notify();
    } catch (_) {}
  }

  void _upsertComment(RoomComment c) {
    final i = comments.indexWhere((x) => x.uuid == c.uuid);
    if (i >= 0) {
      comments[i] = c;
    } else {
      comments.add(c);
      _commentSeq[c.uuid] = ++_seq;
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
        )..seq = ++_seq,
      );
      if (gifts.length > 200) gifts.removeAt(0);
      _notify();
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
    _poll?.cancel();
    unawaited(RoomBackground.stop());
    _unsubscribe();
    rtc.dispose();
    super.dispose();
  }
}
