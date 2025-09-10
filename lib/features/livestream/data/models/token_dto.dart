// lib/features/livestream/data/models/token_dto.dart
class TokenDto {
  final String uuid;
  final String channelName;
  final String rtcToken;
  final String agoraAppId;
  final String apiBaseUrl;
  TokenDto({
    required this.uuid,
    required this.channelName,
    required this.rtcToken,
    required this.agoraAppId,
    required this.apiBaseUrl,
  });
  factory TokenDto.fromJson(Map<String, dynamic> j) => TokenDto(
    uuid: j['uuid'],
    channelName: j['channel_name'],
    rtcToken: j['rtc_token'],
    agoraAppId: j['agora_app_id'],
    apiBaseUrl: j['api_base_url'],
  );
}
