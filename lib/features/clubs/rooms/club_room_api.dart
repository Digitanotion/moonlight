// lib/features/clubs/rooms/club_room_api.dart
//
// HTTP client for club audio / video rooms (API: ClubRoomController).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart'
    show GiftItem;

import 'club_room_models.dart';

class ClubRoomApi {
  ClubRoomApi([Dio? dio]) : _dio = dio ?? sl<DioClient>().dio;
  final Dio _dio;

  static Map<String, dynamic> _data(Response res) =>
      Map<String, dynamic>.from((res.data as Map)['data'] as Map);

  // ── per club ──────────────────────────────────────────────────────────

  Future<List<LiveRoomSummary>> liveRooms(String clubUuid) async {
    final res = await _dio.get('/api/v1/clubs/$clubUuid/rooms');
    final list = ((res.data as Map)['data'] as List?) ?? const [];
    return list
        .map((e) => LiveRoomSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<RoomState> start(
    String clubUuid, {
    required RoomType type,
    int? capacity,
    String? title,
  }) async {
    final res = await _dio.post(
      '/api/v1/clubs/$clubUuid/rooms',
      data: {
        'type': type.name,
        if (capacity != null) 'capacity': capacity,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      },
    );
    return RoomState.fromJson(_data(res));
  }

  // ── per room ──────────────────────────────────────────────────────────

  String _r(String room) => '/api/v1/club-rooms/$room';

  Future<RoomState> state(String room) async =>
      RoomState.fromJson(_data(await _dio.get(_r(room))));

  Future<RoomState> join(String room) async =>
      RoomState.fromJson(_data(await _dio.post('${_r(room)}/join')));

  Future<void> leave(String room) => _dio.post('${_r(room)}/leave');

  Future<void> end(String room) => _dio.post('${_r(room)}/end');

  Future<RtcCredentials> token(String room) async =>
      RtcCredentials.fromJson(_data(await _dio.get('${_r(room)}/token')));

  Future<RoomState> setMic(String room, bool muted) async => RoomState.fromJson(
    _data(await _dio.post('${_r(room)}/mic', data: {'muted': muted})),
  );

  Future<RoomState> requestSeat(String room) async =>
      RoomState.fromJson(_data(await _dio.post('${_r(room)}/seat-request')));

  Future<RoomState> cancelSeat(String room) async =>
      RoomState.fromJson(_data(await _dio.delete('${_r(room)}/seat-request')));

  Future<RoomState> decideSeat(
    String room,
    String userUuid, {
    required bool approve,
  }) async => RoomState.fromJson(
    _data(
      await _dio.post(
        '${_r(room)}/seat-requests/$userUuid/${approve ? 'approve' : 'decline'}',
      ),
    ),
  );

  Future<RoomState> bringDown(
    String room,
    String userUuid, {
    bool kick = false,
  }) async => RoomState.fromJson(
    _data(
      await _dio.post(
        '${_r(room)}/participants/$userUuid/remove',
        data: {'kick': kick},
      ),
    ),
  );

  Future<RoomState> setPremium(
    String room, {
    required bool enabled,
    int? priceCoins,
    String mode = 'host_only',
  }) async => RoomState.fromJson(
    _data(
      await _dio.post(
        '${_r(room)}/premium',
        data: {
          'enabled': enabled,
          if (priceCoins != null) 'price_coins': priceCoins,
          'mode': mode,
        },
      ),
    ),
  );

  Future<RoomState> payPremium(String room) async =>
      RoomState.fromJson(_data(await _dio.post('${_r(room)}/premium/pay')));

  Future<void> gift(
    String room, {
    required String giftCode,
    required String to,
    int quantity = 1,
    required String idempotencyKey,
  }) => _dio.post(
    '${_r(room)}/gift',
    data: {
      'gift_code': giftCode,
      'to': to,
      'quantity': quantity,
      'idempotency_key': idempotencyKey,
    },
  );

  Future<List<RoomComment>> comments(String room, {String? before}) async {
    final res = await _dio.get(
      '${_r(room)}/comments',
      queryParameters: {if (before != null) 'before': before},
    );
    final list = ((res.data as Map)['data'] as List?) ?? const [];
    return list
        .map((e) => RoomComment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<RoomComment> postComment(
    String room, {
    String? body,
    String? replyTo,
    File? media,
  }) async {
    final form = FormData.fromMap({
      if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
      if (replyTo != null) 'reply_to': replyTo,
      if (media != null) 'media': await MultipartFile.fromFile(media.path),
    });
    final res = await _dio.post('${_r(room)}/comments', data: form);
    return RoomComment.fromJson(_data(res));
  }

  Future<RoomComment> editComment(
    String room,
    String commentUuid,
    String body,
  ) async => RoomComment.fromJson(
    _data(
      await _dio.patch(
        '${_r(room)}/comments/$commentUuid',
        data: {'body': body},
      ),
    ),
  );

  Future<void> deleteComment(String room, String commentUuid) =>
      _dio.delete('${_r(room)}/comments/$commentUuid');

  Future<List<GiftItem>> giftCatalog() async {
    final res = await _dio.get('/api/v1/wallet/gifts');
    final list = ((res.data as Map)['data'] as List?) ?? const [];
    return list
        .map((e) => GiftItem.fromJson(Map<String, dynamic>.from(e)))
        .where((g) => g.active)
        .toList();
  }
}
