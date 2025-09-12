part of 'viewer_bloc.dart';

enum ViewerStatus { initial, loading, active }

class ViewerState extends Equatable {
  final ViewerStatus status;
  final HostInfo? host;
  final Duration elapsed;
  final int viewers;
  final int likes;
  final int shares;
  final List<ChatMessage> chat;
  final bool joinRequested;
  final bool showChatUI;
  final bool isPaused;

  final GuestJoinNotice? guest;
  final bool showGuestBanner;

  final GiftNotice? gift;
  final bool showGiftToast;

  const ViewerState({
    required this.status,
    required this.host,
    required this.elapsed,
    required this.viewers,
    required this.likes,
    required this.shares,
    required this.chat,
    required this.joinRequested,
    required this.guest,
    required this.showGuestBanner,
    required this.gift,
    required this.showGiftToast,
    required this.showChatUI,
    required this.isPaused,
  });

  const ViewerState.initial()
    : status = ViewerStatus.initial,
      host = null,
      elapsed = Duration.zero,
      viewers = 0,
      likes = 23500,
      showChatUI = false,
      shares = 0,
      chat = const [],
      joinRequested = false,
      guest = null,
      showGuestBanner = false,
      gift = null,
      showGiftToast = false,
      isPaused = false;

  ViewerState copyWith({
    ViewerStatus? status,
    HostInfo? host,
    Duration? elapsed,
    int? viewers,
    bool? showChatUI,
    int? likes,
    int? shares,
    List<ChatMessage>? chat,
    bool? joinRequested,
    GuestJoinNotice? guest,
    bool? showGuestBanner,
    GiftNotice? gift,
    bool? showGiftToast,
    bool? isPaused,
  }) {
    return ViewerState(
      status: status ?? this.status,
      host: host ?? this.host,
      elapsed: elapsed ?? this.elapsed,
      viewers: viewers ?? this.viewers,
      likes: likes ?? this.likes,
      shares: shares ?? this.shares,
      chat: chat ?? this.chat,
      joinRequested: joinRequested ?? this.joinRequested,
      guest: guest ?? this.guest,
      showGuestBanner: showGuestBanner ?? this.showGuestBanner,
      gift: gift ?? this.gift,
      showGiftToast: showGiftToast ?? this.showGiftToast,
      showChatUI: showChatUI ?? this.showChatUI,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  @override
  List<Object?> get props => [
    status,
    host,
    elapsed,
    viewers,
    likes,
    shares,
    chat,
    joinRequested,
    guest,
    showGuestBanner,
    gift,
    showGiftToast,
    showChatUI,
    isPaused,
  ];
}
