import 'dart:io';
import 'package:dio/dio.dart';

import 'package:moonlight/features/livestream/data/models/go_live_models.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/features/livestream/domain/entities/live_category.dart';
import 'package:moonlight/features/livestream/domain/repositories/go_live_repository.dart';
import 'package:moonlight/features/livestream/domain/entities/live_start_payload.dart'; // <— ADD

class GoLiveRepositoryImpl implements GoLiveRepository {
  final DioClient _client;

  GoLiveRepositoryImpl(this._client);

  @override
  Future<List<LiveCategory>> fetchCategories() async {
    final res = await _client.dio.get('/api/v1/live/categories');
    final data = (res.data as List).cast<dynamic>();
    return data
        .map((e) => CategoryDto.fromJson(Map<String, dynamic>.from(e)))
        .map((d) => LiveCategory(id: d.id, name: d.name))
        .toList();
  }

  @override
  Future<({bool ready, String bestTime, (int, int) estimatedViewers})>
  getPreview({
    required String? title,
    required LiveCategory? category,
    required bool premium,
    required bool allowGuestBox,
    required bool comments,
    required bool showCount,
  }) async {
    final res = await _client.dio.get(
      '/api/v1/live/preview',
      queryParameters: {
        if (title != null) 'title': title,
        if (category != null) 'category_id': category.id,
        'premium': premium,
        'allow_guestbox': allowGuestBox,
        'comments': comments,
        'show_count': showCount,
      },
    );
    final dto = PreviewDto.fromJson(Map<String, dynamic>.from(res.data));
    return (
      ready: dto.ready,
      bestTime: dto.bestTime,
      estimatedViewers: (dto.low, dto.high),
    );
  }

  @override
  Future<bool> isFirstStreamBonusEligible() async {
    final res = await _client.dio.get('/api/v1/live/first-bonus-eligible');
    final dto = FirstBonusDto.fromJson(Map<String, dynamic>.from(res.data));
    return dto.eligible;
  }

  @override
  Future<LiveStartPayload> startStreaming({
    // <— CHANGED return type
    required String title,
    required String categoryId,
    required bool premium,
    required bool allowGuestBox,
    required bool comments,
    required bool showCount,
    required String? coverPath,
    required bool micOn,
    required bool camOn,
  }) async {
    final form = FormData.fromMap({
      'title': title,
      'category_id': categoryId,
      'premium': premium ? '1' : '0',
      'allow_guestbox': allowGuestBox ? '1' : '0',
      'comments': comments ? '1' : '0',
      'show_count': showCount ? '1' : '0',
      'mic_on': micOn ? '1' : '0',
      'cam_on': camOn ? '1' : '0',
      if (coverPath != null && coverPath.isNotEmpty)
        'cover': await MultipartFile.fromFile(
          coverPath,
          filename: coverPath.split(Platform.pathSeparator).last,
        ),
    });

    final res = await _client.dio.post('/api/v1/live/start', data: form);
    final dto = StartLiveResponse.fromJson(Map<String, dynamic>.from(res.data));

    // Map DTO → Domain
    return LiveStartPayload(
      livestreamId: dto.livestreamId,
      channel: dto.channel,
      uidType: dto.uidType,
      uid: dto.uid,
      rtcRole: dto.rtcRole,
      startedAt: dto.startedAt,
      bonusAwarded: dto.bonusAwarded,
      appId: dto.appId,
      rtcToken: dto.rtcToken,
      expiresAt: dto.expiresAt,

      hostDisplayName: dto.hostDisplayName,
      hostBadge: dto.hostBadge,
      hostAvatarUrl: dto.hostAvatarUrl,
      streamTitle: dto.streamTitle,
      initialViewers: dto.streamViewers,
    );
  }
}
