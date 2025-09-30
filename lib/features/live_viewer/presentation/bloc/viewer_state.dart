part of 'viewer_bloc.dart';

enum ViewerStatus { initial, loading, active }

class ViewerState extends Equatable {
  final ViewerStatus status;
  final Duration elapsed;
  final int viewers;
  final int likes;
  final int shares;
  final List<ChatMessage> chat;
  final bool showChatUI;
  final HostInfo? host;
  final GuestJoinNotice? guest;
  final bool showGuestBanner;
  final GiftNotice? gift;
  final bool showGiftToast;
  final bool isPaused;
  final bool isEnded;
  final bool joinRequested;
  final bool awaitingApproval;

  // New properties
  final String? errorMessage;
  final String? currentRole;
  final bool isRemoved;
  final String? removalReason;
  final bool showRoleChangeToast;
  final String? roleChangeMessage;
  final bool showRemovalOverlay;
  final bool shouldNavigateBack;
  final String? activeGuestUuid;

  const ViewerState({
    required this.status,
    required this.elapsed,
    required this.viewers,
    required this.likes,
    required this.shares,
    required this.chat,
    required this.showChatUI,
    this.host,
    this.guest,
    this.showGuestBanner = false,
    this.gift,
    this.showGiftToast = false,
    this.isPaused = false,
    this.isEnded = false,
    this.joinRequested = false,
    this.awaitingApproval = false,
    // New properties with defaults
    this.errorMessage,
    this.currentRole = 'audience',
    this.isRemoved = false,
    this.removalReason,
    this.showRoleChangeToast = false,
    this.roleChangeMessage,
    this.showRemovalOverlay = false,
    this.shouldNavigateBack = false,
    this.activeGuestUuid,
  });

  // Fixed initial method
  static ViewerState initial() => const ViewerState(
    status: ViewerStatus.initial,
    elapsed: Duration.zero,
    viewers: 0,
    likes: 0,
    shares: 0,
    chat: [],
    showChatUI: true,
    // All new properties are initialized
    errorMessage: null,
    currentRole: 'audience',
    isRemoved: false,
    removalReason: null,
    showRoleChangeToast: false,
    roleChangeMessage: null,
    showRemovalOverlay: false,
    shouldNavigateBack: false,
    activeGuestUuid: null,
  );

  ViewerState copyWith({
    ViewerStatus? status,
    Duration? elapsed,
    int? viewers,
    int? likes,
    int? shares,
    List<ChatMessage>? chat,
    bool? showChatUI,
    HostInfo? host,
    GuestJoinNotice? guest,
    bool? showGuestBanner,
    GiftNotice? gift,
    bool? showGiftToast,
    bool? isPaused,
    bool? isEnded,
    bool? joinRequested,
    bool? awaitingApproval,
    // New properties
    String? errorMessage,
    String? currentRole,
    bool? isRemoved,
    String? removalReason,
    bool? showRoleChangeToast,
    String? roleChangeMessage,
    bool? showRemovalOverlay,
    bool? shouldNavigateBack,
    String? activeGuestUuid,
  }) {
    return ViewerState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      viewers: viewers ?? this.viewers,
      likes: likes ?? this.likes,
      shares: shares ?? this.shares,
      chat: chat ?? this.chat,
      showChatUI: showChatUI ?? this.showChatUI,
      host: host ?? this.host,
      guest: guest ?? this.guest,
      showGuestBanner: showGuestBanner ?? this.showGuestBanner,
      gift: gift ?? this.gift,
      showGiftToast: showGiftToast ?? this.showGiftToast,
      isPaused: isPaused ?? this.isPaused,
      isEnded: isEnded ?? this.isEnded,
      joinRequested: joinRequested ?? this.joinRequested,
      awaitingApproval: awaitingApproval ?? this.awaitingApproval,
      // New properties
      errorMessage: errorMessage ?? this.errorMessage,
      currentRole: currentRole ?? this.currentRole,
      isRemoved: isRemoved ?? this.isRemoved,
      removalReason: removalReason ?? this.removalReason,
      showRoleChangeToast: showRoleChangeToast ?? this.showRoleChangeToast,
      roleChangeMessage: roleChangeMessage ?? this.roleChangeMessage,
      showRemovalOverlay: showRemovalOverlay ?? this.showRemovalOverlay,
      shouldNavigateBack: shouldNavigateBack ?? this.shouldNavigateBack,
      activeGuestUuid: activeGuestUuid ?? this.activeGuestUuid,
    );
  }

  @override
  List<Object?> get props => [
    status,
    elapsed,
    viewers,
    likes,
    shares,
    chat,
    showChatUI,
    host,
    guest,
    showGuestBanner,
    gift,
    showGiftToast,
    isPaused,
    isEnded,
    joinRequested,
    awaitingApproval,
    // New properties
    errorMessage,
    currentRole,
    isRemoved,
    removalReason,
    showRoleChangeToast,
    roleChangeMessage,
    showRemovalOverlay,
    shouldNavigateBack,
    activeGuestUuid,
  ];
}
