// lib/features/video_call/domain/repositories/video_call_repository.dart
import 'package:moonlight/features/video_call/data/models/video_call_session_model.dart';

abstract class VideoCallRepository {
  // ── Real-time streams ────────────────────────────────────────────
  // Fired when this user (as callee) receives an incoming call —
  // sourced from the 'video_call_incoming' notification type.
  Stream<Map<String, dynamic>> incomingCallStream();

  // Fired when this user (as caller) is notified the callee accepted —
  // sourced from 'video_call_accepted'. The caller should call join()
  // upon receiving this to get their own Agora token.
  Stream<Map<String, dynamic>> callAcceptedStream();
   Stream<Map<String, dynamic>> callResolvedStream();

  // Routes a video-call event that arrived through a channel OTHER than
  // the live Pusher socket — specifically, FCM's foreground onMessage
  // listener, which is the only delivery mechanism actually confirmed
  // reliable for a backgrounded/locked app. Feeds into the exact same
  // incomingCallStream()/callAcceptedStream()/callResolvedStream()
  // controllers the Pusher handler uses, so every existing listener
  // (VideoCallBloc, screens) reacts identically regardless of source.
  // `payload` must carry 'type' plus either a nested 'meta' map or flat
  // top-level keys (FCM data messages are always flat strings).
  void injectExternalEvent(Map<String, dynamic> payload);

  // ── Directory ────────────────────────────────────────────────────
  Future<List<VideoCallDirectoryUserModel>> fetchDirectory({
    String? country,
    String? username,
    int page = 1,
  });

  // ── Call lifecycle ───────────────────────────────────────────────
  Future<VideoCallSessionModel> initiate({
    required String calleeUserSlug,
    required int minutes,
    required String initiatedFrom, // directory|profile|livestream
    int? livestreamId,
    String? idempotencyKey,
  });

  Future<VideoCallSessionModel> accept(String sessionUuid);
  Future<VideoCallSessionModel> join(String sessionUuid);
  Future<VideoCallSessionModel> reject(String sessionUuid);
  Future<VideoCallSessionModel> extend({
    required String sessionUuid,
    required int minutes,
    String? idempotencyKey,
  });
  Future<VideoCallSessionModel> end({
    required String sessionUuid,
    String? reason,
  });
  Future<VideoCallSessionModel> status(String sessionUuid);
  Future<void> report({
    required String sessionUuid,
    required String reason,
    String? note,
  });

  // ── Streamer controls ────────────────────────────────────────────
  Future<void> toggleOnline(bool online);
  Future<void> toggleEnabled(bool enabled);
  Future<void> broadcast({
    required String audience, // followers|all_males
    String? message,
    String? idempotencyKey,
  });
  Future<void> boost(String duration); // 2_days|1_week

  // ── Cleanup ───────────────────────────────────────────────────────
  void subscribeToCallEvents(); // call once, e.g. from app startup after login

  /// Re-subscribes to the correct personal notification channel once the
  /// real logged-in user's uuid is known. Needed because VideoCallBloc
  /// (and this repository underneath it) is constructed at app launch,
  /// before login completes — the initial subscription may be to an
  /// empty/placeholder uuid. Call this from the auth state listener the
  /// moment AuthAuthenticated fires.
  void resubscribeForUser(String userUuid);

  void dispose();
}