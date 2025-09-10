// lib/features/livestream/data/datasources/livestream_remote_ds.dart
import 'package:dio/dio.dart';
import '../models/livestream_dto.dart';
import '../models/token_dto.dart';
import '../models/message_dto.dart';
import '../models/gift_dto.dart';

class LivestreamRemoteDataSource {
  final Dio dio;
  LivestreamRemoteDataSource(this.dio);

  Future<List<LivestreamDto>> getActive() async {
    final res = await dio.get('/api/v1/livestreams/active');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => LivestreamDto.fromJson(e)).toList();
  }

  Future<TokenDto> requestToken(
    String lsUuid, {
    String role = 'audience',
  }) async {
    final res = await dio.post(
      '/api/v1/livestreams/$lsUuid/token',
      data: {'role': role},
    );
    return TokenDto.fromJson(res.data);
  }

  Future<TokenDto> start({
    required String title,
    String visibility = 'public',
    bool? record,
    String? clubUuid,
    List<String>? invitees,
  }) async {
    final res = await dio.post(
      '/api/v1/livestreams',
      data: {
        'title': title,
        if (record != null) 'record': record,
        'visibility': visibility,
        if (clubUuid != null) 'club_uuid': clubUuid,
        if (invitees != null) 'invitees': invitees,
      },
    );
    return TokenDto.fromJson(
      res.data,
    ); // includes channel_name, rtc_token, app id
  }

  Future<void> stop(String lsUuid) async {
    await dio.post('/api/v1/livestreams/$lsUuid/stop');
  }

  Future<void> pause(String lsUuid) async {
    await dio.post('/api/v1/livestreams/$lsUuid/pause');
  }

  Future<void> resume(String lsUuid) async {
    await dio.post('/api/v1/livestreams/$lsUuid/resume');
  }

  Future<List<MessageDto>> getMessages(String lsUuid, {String? cursor}) async {
    final res = await dio.get(
      '/api/v1/livestreams/$lsUuid/messages',
      queryParameters: {'cursor': cursor},
    );
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => MessageDto.fromJson(e)).toList();
  }

  Future<MessageDto> sendMessage(String lsUuid, String text) async {
    final res = await dio.post(
      '/api/v1/livestreams/$lsUuid/messages',
      data: {'text': text},
    );
    return MessageDto.fromJson(res.data);
  }

  Future<GiftResponseDto> sendGift(
    String lsUuid,
    String giftType,
    int coins,
  ) async {
    final res = await dio.post(
      '/api/v1/livestreams/$lsUuid/gifts',
      data: {'gift_type': giftType, 'coins': coins},
    );
    return GiftResponseDto.fromJson(res.data);
  }

  Future<Map<String, dynamic>> getViewers(String lsUuid) async {
    final res = await dio.get('/api/v1/livestreams/$lsUuid/viewers');
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> requestCohost(String lsUuid, {String? note}) async {
    await dio.post(
      '/api/v1/livestreams/$lsUuid/cohosts/requests',
      data: {'note': note},
    );
  }

  Future<List<Map<String, dynamic>>> getRequests(String lsUuid) async {
    final res = await dio.get('/api/v1/livestreams/$lsUuid/cohosts/requests');
    final list = (res.data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> acceptRequest(String lsUuid, String userUuid) async {
    await dio.post(
      '/api/v1/livestreams/$lsUuid/cohosts/accept',
      data: {'user_uuid': userUuid},
    );
  }

  Future<void> declineRequest(String lsUuid, String userUuid) async {
    await dio.post(
      '/api/v1/livestreams/$lsUuid/cohosts/decline',
      data: {'user_uuid': userUuid},
    );
  }

  Future<void> removeCohost(String lsUuid, String userUuid) async {
    await dio.delete('/api/v1/livestreams/$lsUuid/cohosts/$userUuid');
  }
}
