import 'package:moonlight/features/livestream/domain/entities/live_start_payload.dart';

class LiveSessionTracker {
  LiveStartPayload? _current;

  bool get isActive => _current != null;
  LiveStartPayload? get current => _current;

  void start(LiveStartPayload payload) => _current = payload;
  void end() => _current = null;
}
