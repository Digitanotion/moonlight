// lib/features/livestream/data/models/livestream_dto.dart
import '../../domain/entities/livestream.dart';

class LivestreamDto {
  final String uuid;
  final String title;
  final String channelName;
  final String visibility;
  final String status;
  final DateTime? startTime;
  final HostMini host;

  LivestreamDto({
    required this.uuid,
    required this.title,
    required this.channelName,
    required this.visibility,
    required this.status,
    required this.startTime,
    required this.host,
  });

  factory LivestreamDto.fromJson(Map<String, dynamic> j) => LivestreamDto(
    uuid: j['uuid'],
    title: j['title'] ?? '',
    channelName: j['channel_name'] ?? '',
    visibility: j['visibility'] ?? 'public',
    status: j['status'] ?? 'live',
    startTime: j['start_time'] != null
        ? DateTime.tryParse(j['start_time'])
        : null,
    host: HostMini.fromJson(j['host'] ?? const {}),
  );

  Livestream toEntity() => Livestream(
    uuid: uuid,
    title: title,
    channelName: channelName,
    visibility: visibility,
    status: status,
    startTime: startTime,
    host: host,
  );
}

class HostMini {
  final String uuid;
  final String display;
  final String? avatarUrl;
  HostMini({required this.uuid, required this.display, this.avatarUrl});
  factory HostMini.fromJson(Map<String, dynamic> j) => HostMini(
    uuid: j['uuid'] ?? '',
    display: j['display'] ?? '',
    avatarUrl: j['avatar_url'],
  );
}
