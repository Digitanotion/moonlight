import 'package:moonlight/features/livestream/domain/entities/live_join_request.dart';

abstract class LiveSessionRepository {
  /// Simulated incoming chat messages from server.
  Stream<LiveChatMessage> chatStream();

  /// Simulated viewer count updates.
  Stream<int> viewersStream();

  /// Start/Stop a live session (no-ops for fake).
  Future<void> startSession({required String topic});
  Future<void> endSession();

  // Join requests
  Stream<LiveJoinRequest> joinRequestStream();
  Future<void> acceptJoinRequest(String requestId);
  Future<void> declineJoinRequest(String requestId);

  void dispose();
}

class LiveChatMessage {
  final String handle;
  final String text;
  LiveChatMessage(this.handle, this.text);
}
