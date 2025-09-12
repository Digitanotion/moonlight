// =============================================
// LAYER: DOMAIN REPOSITORY CONTRACT
// =============================================

// -----------------------------
// FILE: lib/features/live/domain/repositories/live_repository.dart
// -----------------------------
import '../entities/live_entities.dart';

abstract class LiveRepository {
  Stream<LiveMeta> meta$();
  Stream<List<ChatMessage>> chat$();
  Stream<GiftEvent?> giftBanner$();
  Stream<GuestJoinEvent?> guestBanner$();

  Future<void> sendComment(String text);
  Future<void> requestToJoin();
  Future<void> leaveStream();
}
