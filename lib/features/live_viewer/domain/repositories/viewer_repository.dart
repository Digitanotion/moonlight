import 'package:moonlight/features/live_viewer/domain/entities.dart';

abstract class ViewerRepository {
  Future<HostInfo> fetchHostInfo();

  Stream<Duration> watchLiveClock();
  Stream<int> watchViewerCount();
  Stream<ChatMessage> watchChat();
  Stream<GuestJoinNotice> watchGuestJoins();
  Stream<GiftNotice> watchGifts();
  Stream<bool> watchPause();
  Stream<void> watchEnded();

  /// Emits:
  ///  - true  → this viewer's join request accepted
  ///  - false → declined (or ended)
  Stream<bool> watchMyApproval();

  Future<void> sendComment(String text);
  Future<int> like();
  Future<int> share();

  /// Sends a *view-only* join request (NOT co-host).
  Future<void> requestToJoin();

  Future<bool> toggleFollow(bool follow);
  Stream<String> watchErrors();
  Stream<String> watchParticipantRoleChanges();
  Stream<String> watchParticipantRemovals();
  // Catalog
  Future<(List<GiftItem>, String? catalogVersion)> fetchGiftCatalog();

  // Send gift
  Future<GiftSendResult> sendGift({
    required String giftCode,
    required String toUserUuid,
    required String livestreamId,
    int quantity = 1,
  });

  // Broadcast stream for gift.sent events
  Stream<GiftBroadcast> watchGiftBroadcasts();
  Future<int?> fetchWalletBalance();

  // bool get isMicMuted;
  // bool get isCamMuted;
  void dispose();
}
