import 'dart:async';
import '../entities.dart';

abstract class ViewerRepository {
  Future<HostInfo> fetchHostInfo();

  /// Live streams (wire to your sockets / RTC callbacks later)
  Stream<Duration> watchLiveClock(); // 00:01, 00:02, ...
  Stream<int> watchViewerCount(); // 247, ...
  Stream<ChatMessage> watchChat(); // incoming chat
  Stream<GuestJoinNotice> watchGuestJoins(); // guest banner
  Stream<GiftNotice> watchGifts(); // gift toast
  Stream<bool> watchPause();

  /// Actions
  Future<void> sendComment(String text);
  Future<int> like(); // returns new like count
  Future<int> share(); // returns new share count
  Future<void> requestToJoin();
  Future<bool> toggleFollow(bool follow); // returns new follow state

  /// Dispose if needed
  void dispose();
}
