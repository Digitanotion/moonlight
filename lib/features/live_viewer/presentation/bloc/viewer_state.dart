// lib/features/live_viewer/presentation/bloc/viewer_state.dart
part of 'viewer_bloc.dart';

enum ViewerStatus { initial, loading, active, reconnecting, ended, error }

class ViewerState extends Equatable {
  // ============ CORE ============
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
  final bool showGiftSheet;
  final List<GiftItem> giftCatalog;
  final String? giftCatalogVersion;
  final int? walletBalanceCoins;
  final bool isSendingGift;
  final String? sendErrorMessage;
  final List<GiftBroadcast> giftOverlayQueue;
  final String? errorMessage;
  final String? currentRole;
  final bool isRemoved;
  final String? removalReason;
  final bool showRoleChangeToast;
  final String? roleChangeMessage;
  final bool showRemovalOverlay;
  final bool shouldNavigateBack;
  final String? activeGuestUuid;

  // ============ ENHANCED ============
  final ViewMode viewMode;
  final NetworkStatus networkStatus;
  final GuestControlsState guestControls;
  final bool isReconnecting;
  final int reconnectAttempts;
  final String? reconnectMessage;
  final bool showReconnectOverlay;
  final bool showNetworkStatus;

  // ============ STREAM HEALTH ============
  final bool isStreamUnstable;
  final String? streamUnstableMessage;
  final bool requiresPremiumPayment;
  final int? premiumEntryFeeCoins;

  const ViewerState({
    required this.status,
    required this.elapsed,
    required this.viewers,
    required this.likes,
    required this.shares,
    required this.chat,
    this.showChatUI = true,
    this.host,
    this.guest,
    this.showGuestBanner = false,
    this.gift,
    this.showGiftToast = false,
    this.isPaused = false,
    this.isEnded = false,
    this.joinRequested = false,
    this.awaitingApproval = false,
    this.showGiftSheet = false,
    this.giftCatalog = const [],
    this.giftCatalogVersion,
    this.walletBalanceCoins,
    this.isSendingGift = false,
    this.sendErrorMessage,
    this.giftOverlayQueue = const [],
    this.errorMessage,
    this.currentRole = 'audience',
    this.isRemoved = false,
    this.removalReason,
    this.showRoleChangeToast = false,
    this.roleChangeMessage,
    this.showRemovalOverlay = false,
    this.shouldNavigateBack = false,
    this.activeGuestUuid,
    // Enhanced
    this.viewMode = ViewMode.viewer,
    this.networkStatus = const NetworkStatus(
      selfQuality: NetworkQuality.unknown,
      hostQuality: NetworkQuality.unknown,
      guestQuality: null,
      isReconnecting: false,
      reconnectAttempts: 0,
      lastDisconnection: null,
    ),
    this.guestControls = const GuestControlsState(),
    this.isReconnecting = false,
    this.reconnectAttempts = 0,
    this.reconnectMessage,
    this.showReconnectOverlay = false,
    this.showNetworkStatus = false, // OFF by default — no network UI flags
    // Health
    this.isStreamUnstable = false,
    this.streamUnstableMessage,
    this.requiresPremiumPayment = false,
    this.premiumEntryFeeCoins,
  });

  static ViewerState initial() => const ViewerState(
    status: ViewerStatus.initial,
    elapsed: Duration.zero,
    viewers: 0,
    likes: 0,
    shares: 0,
    chat: [],
    showChatUI: true,
    viewMode: ViewMode.viewer,
    networkStatus: NetworkStatus(
      selfQuality: NetworkQuality.unknown,
      hostQuality: NetworkQuality.unknown,
      guestQuality: null,
      isReconnecting: false,
      reconnectAttempts: 0,
      lastDisconnection: null,
    ),
    guestControls: GuestControlsState(),
    isReconnecting: false,
    reconnectAttempts: 0,
    showReconnectOverlay: false,
    showNetworkStatus: false,
    isStreamUnstable: false,
    requiresPremiumPayment: false,
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
    bool? showGiftSheet,
    List<GiftItem>? giftCatalog,
    String? giftCatalogVersion,
    int? walletBalanceCoins,
    bool? isSendingGift,
    String? sendErrorMessage,
    List<GiftBroadcast>? giftOverlayQueue,
    String? errorMessage,
    String? currentRole,
    bool? isRemoved,
    String? removalReason,
    bool? showRoleChangeToast,
    String? roleChangeMessage,
    bool? showRemovalOverlay,
    bool? shouldNavigateBack,
    String? activeGuestUuid,
    // Enhanced
    ViewMode? viewMode,
    NetworkStatus? networkStatus,
    GuestControlsState? guestControls,
    bool? isReconnecting,
    int? reconnectAttempts,
    String? reconnectMessage,
    bool? showReconnectOverlay,
    bool? showNetworkStatus,
    // Health
    bool? isStreamUnstable,
    String? streamUnstableMessage,
    bool? requiresPremiumPayment,
    int? premiumEntryFeeCoins,
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
      showGiftSheet: showGiftSheet ?? this.showGiftSheet,
      giftCatalog: giftCatalog ?? this.giftCatalog,
      giftCatalogVersion: giftCatalogVersion ?? this.giftCatalogVersion,
      walletBalanceCoins: walletBalanceCoins ?? this.walletBalanceCoins,
      isSendingGift: isSendingGift ?? this.isSendingGift,
      sendErrorMessage: sendErrorMessage ?? this.sendErrorMessage,
      giftOverlayQueue: giftOverlayQueue ?? this.giftOverlayQueue,
      errorMessage: errorMessage ?? this.errorMessage,
      currentRole: currentRole ?? this.currentRole,
      isRemoved: isRemoved ?? this.isRemoved,
      removalReason: removalReason ?? this.removalReason,
      showRoleChangeToast: showRoleChangeToast ?? this.showRoleChangeToast,
      roleChangeMessage: roleChangeMessage ?? this.roleChangeMessage,
      showRemovalOverlay: showRemovalOverlay ?? this.showRemovalOverlay,
      shouldNavigateBack: shouldNavigateBack ?? this.shouldNavigateBack,
      activeGuestUuid: activeGuestUuid ?? this.activeGuestUuid,
      viewMode: viewMode ?? this.viewMode,
      networkStatus: networkStatus ?? this.networkStatus,
      guestControls: guestControls ?? this.guestControls,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      reconnectMessage: reconnectMessage ?? this.reconnectMessage,
      showReconnectOverlay: showReconnectOverlay ?? this.showReconnectOverlay,
      showNetworkStatus: showNetworkStatus ?? this.showNetworkStatus,
      isStreamUnstable: isStreamUnstable ?? this.isStreamUnstable,
      streamUnstableMessage:
          streamUnstableMessage ?? this.streamUnstableMessage,
      requiresPremiumPayment:
          requiresPremiumPayment ?? this.requiresPremiumPayment,
      premiumEntryFeeCoins: premiumEntryFeeCoins ?? this.premiumEntryFeeCoins,
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
    showGiftSheet,
    giftCatalog,
    giftCatalogVersion,
    walletBalanceCoins,
    isSendingGift,
    sendErrorMessage,
    giftOverlayQueue,
    errorMessage,
    currentRole,
    isRemoved,
    removalReason,
    showRoleChangeToast,
    roleChangeMessage,
    showRemovalOverlay,
    shouldNavigateBack,
    activeGuestUuid,
    viewMode,
    networkStatus,
    guestControls,
    isReconnecting,
    reconnectAttempts,
    reconnectMessage,
    showReconnectOverlay,
    showNetworkStatus,
    isStreamUnstable,
    streamUnstableMessage,
    requiresPremiumPayment,
    premiumEntryFeeCoins,
  ];
}
