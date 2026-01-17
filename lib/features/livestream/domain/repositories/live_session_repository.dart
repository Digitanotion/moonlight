import 'package:moonlight/features/livestream/data/models/live_session_models.dart';
import 'package:moonlight/features/livestream/data/models/premium_package_model.dart';
import 'package:moonlight/features/livestream/data/models/premium_status_model.dart';
import 'package:moonlight/features/livestream/data/models/wallet_model.dart';
import 'package:moonlight/features/livestream/domain/entities/live_end_analytics.dart';
import 'package:moonlight/features/livestream/domain/entities/live_join_request.dart';
import 'package:moonlight/features/livestream/domain/entities/live_entities.dart';

abstract class LiveSessionRepository {
  // Streams surfaced to Host Bloc/UI
  Stream<LiveChatMessage> chatStream();
  Stream<int> viewersStream();
  Stream<bool> pauseStream();
  Stream<LiveJoinRequest> joinRequestStream();

  // NEW
  Stream<GiftEvent> giftsStream();
  Stream<bool> endedStream();
  Stream<JoinHandled> joinHandledStream();
  Stream<String?> activeGuestUuidStream();

  /// Ends the livestream on the server and returns final analytics.
  Future<LiveEndAnalytics> endAndFetchAnalytics();

  // Session control
  Future<void> startSession({required String topic});
  Future<void> endSession();
  Future<void> togglePause();
  void setLocalPause(bool paused);

  // Join moderation
  Future<void> acceptJoinRequest(String requestId);
  Future<void> declineJoinRequest(String requestId);
  Future<void> sendChatMessage(String text);
  Future<List<HostGiftBroadcast>> fetchCollectedGifts();

  Future<List<PremiumPackageModel>> fetchCoinPackages();
  Future<WalletModel> fetchWallet();
  Future<PremiumStatusModel> activatePremium({
    required int livestreamId,
    required String packageId,
    required String packageName,
    required String coins,
    String? idempotencyKey,
  });
  Future<PremiumStatusModel> cancelPremium({
    required int livestreamId,
    String? idempotencyKey,
  });

  Future<void> restartStreams();
  Stream<PremiumStatusModel>
  premiumStatusStream(); // emits when server pushes premium_status_changed via pusher
  Future<void> makeGuest(String userUuid);

  void dispose();
}

// tiny data model for join-handled echo
class JoinHandled {
  final String id;
  final bool accepted;
  const JoinHandled(this.id, this.accepted);
}

// host chat message (kept here as before)
class LiveChatMessage {
  final String handle;
  final String text;
  final String role;
  final String? avatarUrl;
  LiveChatMessage(this.handle, this.text, this.role, this.avatarUrl);
}
