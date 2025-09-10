// lib/features/livestream/domain/entities/livestream.dart
class Livestream {
  final String uuid;
  final String title;
  final String channelName;
  final String visibility;
  final String status; // live|paused|ended
  final DateTime? startTime;
  final dynamic host; // HostMini DTO used in UI directly
  Livestream({
    required this.uuid,
    required this.title,
    required this.channelName,
    required this.visibility,
    required this.status,
    required this.startTime,
    required this.host,
  });
}
