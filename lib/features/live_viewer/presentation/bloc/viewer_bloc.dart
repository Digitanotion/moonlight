// lib/features/live_viewer/presentation/bloc/viewer_bloc.dart - ENHANCED
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';
import 'package:moonlight/features/live_viewer/domain/repositories/viewer_repository.dart';
import 'package:moonlight/features/live_viewer/presentation/services/live_stream_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/network_monitor_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/reconnection_service.dart';
import 'package:moonlight/features/live_viewer/presentation/services/role_change_service.dart';

part 'viewer_event.dart';
part 'viewer_state.dart';

class ViewerBloc extends Bloc<ViewerEvent, ViewerState> {
  final ViewerRepository repo;
  final LiveStreamService? liveStreamService;
  final AgoraViewerService? agoraViewerService;
  final NetworkMonitorService? networkMonitorService;
  final ReconnectionService? reconnectionService;
  final RoleChangeService? roleChangeService;

  // Existing subscriptions
  StreamSubscription? _clockSub, _viewerSub, _chatSub, _guestSub, _giftSub;
  StreamSubscription? _pauseSub, _endedSub, _approvalSub;
  StreamSubscription? _errorSub, _roleChangeSub, _removalSub;
  StreamSubscription<String?>? _activeGuestSub;
  StreamSubscription<GiftBroadcast>? _giftBroadcastSub;

  // New subscriptions for services
  StreamSubscription<NetworkStatus>? _networkStatusSub;
  StreamSubscription<ConnectionStats>? _connectionStatsSub;
  StreamSubscription<ReconnectionStatus>? _reconnectionSub;
  StreamSubscription<RoleChangeResult>? _roleChangeResultSub;
  StreamSubscription<NetworkQuality>? _hostQualitySub;
  StreamSubscription<NetworkQuality>? _selfQualitySub;
  StreamSubscription<NetworkQuality>? _guestQualitySub;
  StreamSubscription<ConnectionState>? _connectionStateSub;

  bool _isClosing = false;
  bool _isStarted = false;
  final List<String> _eventLog = [];

  ViewerBloc(
    this.repo, {
    this.liveStreamService,
    this.agoraViewerService,
    this.networkMonitorService,
    this.reconnectionService,
    this.roleChangeService,
  }) : super(ViewerState.initial()) {
    _logEvent('BLOC_CREATED', 'Bloc created with enhanced services');

    // ============ REGISTER ALL EVENT HANDLERS ============

    // Core lifecycle
    on<ViewerStarted>(_onStarted);

    // Time and counters
    on<_Ticked>(
      (e, emit) => _safeEmit(emit, state.copyWith(elapsed: e.elapsed)),
    );
    on<_ViewerCountUpdated>(
      (e, emit) => _safeEmit(emit, state.copyWith(viewers: e.count)),
    );
    on<_ChatArrived>(_onChatArrived);
    on<_GuestJoined>(_onGuestJoined);
    on<_GiftArrived>(_onGiftArrived);
    on<GuestBannerDismissed>(
      (e, emit) => _safeEmit(emit, state.copyWith(showGuestBanner: false)),
    );
    on<GiftToastDismissed>(
      (e, emit) => _safeEmit(emit, state.copyWith(showGiftToast: false)),
    );

    // User actions
    on<FollowToggled>(_onFollowToggled);
    on<CommentSent>(_onCommentSent);
    on<LikePressed>(_onLikePressed);
    on<SharePressed>(_onSharePressed);
    on<RequestToJoinPressed>(_onRequestToJoinPressed);

    // UI toggles
    on<ChatVisibilityToggled>(
      (e, emit) =>
          _safeEmit(emit, state.copyWith(showChatUI: !state.showChatUI)),
    );
    on<ChatShowRequested>(
      (e, emit) => _safeEmit(emit, state.copyWith(showChatUI: true)),
    );
    on<ChatHideRequested>(
      (e, emit) => _safeEmit(emit, state.copyWith(showChatUI: false)),
    );

    // Stream events
    on<_PauseChanged>(
      (e, emit) => _safeEmit(emit, state.copyWith(isPaused: e.paused)),
    );
    on<_LiveEnded>((e, emit) => _safeEmit(emit, state.copyWith(isEnded: true)));
    on<_MyApprovalChanged>(_onMyApprovalChanged);
    on<ErrorOccurred>(_onErrorOccurred);
    on<ParticipantRoleChanged>(_onParticipantRoleChanged);
    on<ParticipantRemoved>(_onParticipantRemoved);
    on<RoleChangeToastDismissed>(
      (e, emit) => _safeEmit(emit, state.copyWith(showRoleChangeToast: false)),
    );
    on<NavigateBackRequested>(
      (e, emit) => _safeEmit(emit, state.copyWith(shouldNavigateBack: true)),
    );
    on<_ActiveGuestUpdated>(
      (e, emit) => _safeEmit(emit, state.copyWith(activeGuestUuid: e.uuid)),
    );

    // Gift system
    on<GiftSheetRequested>(
      (e, emit) => _safeEmit(emit, state.copyWith(showGiftSheet: true)),
    );
    on<GiftSheetClosed>(
      (e, emit) => _safeEmit(
        emit,
        state.copyWith(showGiftSheet: false, sendErrorMessage: null),
      ),
    );
    on<GiftsFetchRequested>(_onGiftsFetchRequested);
    on<GiftSendRequested>(_onGiftSendRequested);
    on<GiftSendSucceeded>(_onGiftSendSucceeded);
    on<GiftSendFailed>(
      (e, emit) => _safeEmit(
        emit,
        state.copyWith(isSendingGift: false, sendErrorMessage: e.message),
      ),
    );
    on<GiftBroadcastReceived>(_onGiftBroadcastReceived);
    on<GiftOverlayDequeued>(_onGiftOverlayDequeued);

    // ============ NEW EVENT HANDLERS ============

    // Network monitoring
    on<NetworkQualityUpdated>(_onNetworkQualityUpdated);
    on<ConnectionStatsUpdated>(
      (e, emit) =>
          _logEvent('CONNECTION_STATS', 'Updated: ${e.stats.bitrate}kbps'),
    );

    // Reconnection
    on<ConnectionLost>(_onConnectionLost);
    on<ReconnectionStarted>(_onReconnectionStarted);
    on<ReconnectionSucceeded>(_onReconnectionSucceeded);
    on<ReconnectionFailed>(_onReconnectionFailed);
    on<ReconnectionOverlayDismissed>(
      (e, emit) => _safeEmit(emit, state.copyWith(showReconnectOverlay: false)),
    );

    // Guest controls
    on<GuestVideoToggled>(_onGuestVideoToggled);
    on<GuestAudioToggled>(_onGuestAudioToggled);
    on<GuestControlsUpdated>(
      (e, emit) => _safeEmit(emit, state.copyWith(guestControls: e.controls)),
    );

    // Mode switching
    on<ModeSwitched>(_onModeSwitched);
    on<NetworkStatusVisibilityToggled>(
      (e, emit) =>
          _safeEmit(emit, state.copyWith(showNetworkStatus: e.visible)),
    );
  }

  // ============ EXISTING METHODS (ENHANCED) ============

  void _logEvent(String type, String message) {
    final timestamp = DateTime.now();
    final logEntry = '[$timestamp] $type: $message';
    _eventLog.add(logEntry);

    if (_eventLog.length > 100) {
      _eventLog.removeAt(0);
    }

    debugPrint('🔵 BLOC: $logEntry');
  }

  Future<void> _onStarted(
    ViewerStarted event,
    Emitter<ViewerState> emit,
  ) async {
    if (_isStarted) {
      _logEvent('START_IGNORED', 'Already started');
      return;
    }

    _isStarted = true;
    _logEvent('STARTING', 'Viewer started with enhanced services');

    emit(state.copyWith(status: ViewerStatus.loading));

    try {
      // Fetch host info
      final host = await repo.fetchHostInfo();
      _logEvent('HOST_FETCHED', 'Host: ${host.name}');

      // Fetch wallet balance
      int? walletBalance;
      try {
        walletBalance = await repo.fetchWalletBalance();
        _logEvent('WALLET_FETCHED', 'Balance: $walletBalance');
      } catch (e) {
        _logEvent('WALLET_FAILED', 'Error: $e');
        walletBalance = null;
      }

      // Update state
      emit(
        state.copyWith(
          status: ViewerStatus.active,
          host: host,
          walletBalanceCoins: walletBalance,
          joinRequested: true,
          awaitingApproval: false,
        ),
      );
      _logEvent('STATE_ACTIVE', 'Ready');

      // Setup subscriptions
      _setupSubscriptions();

      // Start services if available
      _startEnhancedServices();

      _logEvent('SERVICES_STARTED', 'All services active');
    } catch (e, stack) {
      _logEvent('START_FAILED', 'Error: $e');
      debugPrint('Stack: $stack');

      emit(
        state.copyWith(
          status:
              ViewerStatus.active, // Still show UI even if some features fail
          errorMessage: 'Failed to start: ${e.toString()}',
        ),
      );
    }
  }

  void _startEnhancedServices() {
    // Start network monitoring
    networkMonitorService?.startMonitoring();

    // Start reconnection monitoring
    reconnectionService?.startMonitoring();

    // Setup service subscriptions
    _setupServiceSubscriptions();
  }

  void _setupServiceSubscriptions() {
    // Network monitoring
    if (networkMonitorService != null) {
      _networkStatusSub = networkMonitorService!.watchNetworkStatus().listen(
        (status) => add(
          NetworkQualityUpdated(
            selfQuality: status.selfQuality,
            hostQuality: status.hostQuality,
            guestQuality: status.guestQuality,
          ),
        ),
        onError: (e) => _logEvent('NETWORK_STATUS_ERROR', 'Error: $e'),
      );

      _connectionStatsSub = networkMonitorService!
          .watchConnectionStats()
          .listen(
            (stats) => add(ConnectionStatsUpdated(stats)),
            onError: (e) => _logEvent('CONNECTION_STATS_ERROR', 'Error: $e'),
          );

      networkMonitorService!.watchNetworkIssues().listen(
        (issue) => add(ErrorOccurred('Network: $issue')),
        onError: (e) => _logEvent('NETWORK_ISSUE_ERROR', 'Error: $e'),
      );
    }

    // Reconnection service
    if (reconnectionService != null) {
      _reconnectionSub = reconnectionService!.watchReconnection().listen((
        status,
      ) {
        if (status.isActive) {
          add(ReconnectionStarted());
        } else if (status.isSuccessful) {
          add(ReconnectionSucceeded(status.attempt));
        } else if (status.isFailed || status.gaveUp) {
          add(
            ReconnectionFailed(
              error: status.message ?? 'Unknown error',
              attempts: status.attempt,
            ),
          );
        }
      }, onError: (e) => _logEvent('RECONNECTION_ERROR', 'Error: $e'));
    }

    // Role change service
    if (roleChangeService != null) {
      _roleChangeResultSub = roleChangeService!.watchRoleChanges().listen((
        result,
      ) {
        if (result.state == RoleChangeState.promoted) {
          add(ModeSwitched(ViewMode.guest));
          add(ErrorOccurred('You are now a guest!'));
        } else if (result.state == RoleChangeState.demoted) {
          add(ModeSwitched(ViewMode.viewer));
          add(ErrorOccurred('You are back in the audience.'));
        } else if (result.state == RoleChangeState.failed) {
          add(ErrorOccurred(result.error ?? 'Role change failed'));
        }
      }, onError: (e) => _logEvent('ROLE_CHANGE_ERROR', 'Error: $e'));

      // Guest controls state
      roleChangeService!.guestAudioMuted.addListener(() {
        add(GuestControlsUpdated(roleChangeService!.getGuestControlsState()));
      });

      roleChangeService!.guestVideoMuted.addListener(() {
        add(GuestControlsUpdated(roleChangeService!.getGuestControlsState()));
      });
    }

    // Live stream service network quality
    if (liveStreamService != null) {
      _hostQualitySub = liveStreamService!.watchHostNetworkQuality().listen(
        (quality) => add(
          NetworkQualityUpdated(
            selfQuality: state.networkStatus.selfQuality,
            hostQuality: quality,
            guestQuality: state.networkStatus.guestQuality,
          ),
        ),
        onError: (e) => _logEvent('HOST_QUALITY_ERROR', 'Error: $e'),
      );

      _selfQualitySub = liveStreamService!.watchSelfNetworkQuality().listen(
        (quality) => add(
          NetworkQualityUpdated(
            selfQuality: quality,
            hostQuality: state.networkStatus.hostQuality,
            guestQuality: state.networkStatus.guestQuality,
          ),
        ),
        onError: (e) => _logEvent('SELF_QUALITY_ERROR', 'Error: $e'),
      );

      final guestStream = liveStreamService!.watchGuestNetworkQuality();
      if (guestStream != null) {
        _guestQualitySub = guestStream.listen(
          (quality) => add(
            NetworkQualityUpdated(
              selfQuality: state.networkStatus.selfQuality,
              hostQuality: state.networkStatus.hostQuality,
              guestQuality: quality,
            ),
          ),
          onError: (e) => _logEvent('GUEST_QUALITY_ERROR', 'Error: $e'),
        );
      }

      _connectionStateSub = liveStreamService!.watchConnectionState().listen((
        connectionState,
      ) {
        if (connectionState == ConnectionState.disconnected) {
          add(
            ConnectionLost(
              timestamp: DateTime.now(),
              reason: 'Connection lost',
            ),
          );
        }
      }, onError: (e) => _logEvent('CONNECTION_STATE_ERROR', 'Error: $e'));
    }
  }

  // ============ NEW EVENT HANDLERS ============

  Future<void> _onNetworkQualityUpdated(
    NetworkQualityUpdated event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(
        networkStatus: state.networkStatus.copyWith(
          selfQuality: event.selfQuality,
          hostQuality: event.hostQuality,
          guestQuality: event.guestQuality,
        ),
      ),
    );
    _logEvent(
      'NETWORK_QUALITY',
      'Self: ${event.selfQuality}, Host: ${event.hostQuality}, Guest: ${event.guestQuality}',
    );
  }

  Future<void> _onConnectionLost(
    ConnectionLost event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(
        isReconnecting: true,
        reconnectAttempts: 0,
        reconnectMessage: 'Connection lost. Reconnecting...',
        showReconnectOverlay: true,
        networkStatus: state.networkStatus.copyWith(
          isReconnecting: true,
          lastDisconnection: event.timestamp,
        ),
      ),
    );

    _logEvent('CONNECTION_LOST', 'Reason: ${event.reason}');

    // Trigger reconnection attempt
    reconnectionService?.attemptReconnection();
  }

  Future<void> _onReconnectionStarted(
    ReconnectionStarted event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(
        isReconnecting: true,
        reconnectMessage: 'Attempting to reconnect...',
        showReconnectOverlay: true,
      ),
    );
    _logEvent('RECONNECTION_STARTED', 'Starting reconnection');
  }

  Future<void> _onReconnectionSucceeded(
    ReconnectionSucceeded event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(
        isReconnecting: false,
        reconnectAttempts: event.attempts,
        reconnectMessage: 'Reconnected successfully!',
        showReconnectOverlay: false,
        networkStatus: state.networkStatus.copyWith(
          isReconnecting: false,
          reconnectAttempts: event.attempts,
        ),
      ),
    );

    _logEvent('RECONNECTION_SUCCEEDED', 'Attempts: ${event.attempts}');

    // Clear reconnect message after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isClosing && !isClosed) {
        add(const ErrorOccurred(''));
      }
    });
  }

  Future<void> _onReconnectionFailed(
    ReconnectionFailed event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(
        isReconnecting: false,
        reconnectAttempts: event.attempts,
        reconnectMessage: 'Failed to reconnect: ${event.error}',
        showReconnectOverlay: true,
        networkStatus: state.networkStatus.copyWith(
          isReconnecting: false,
          reconnectAttempts: event.attempts,
        ),
      ),
    );

    _logEvent(
      'RECONNECTION_FAILED',
      'Attempts: ${event.attempts}, Error: ${event.error}',
    );
  }

  Future<void> _onGuestVideoToggled(
    GuestVideoToggled event,
    Emitter<ViewerState> emit,
  ) async {
    try {
      await liveStreamService?.setCamEnabled(event.enabled);
      _safeEmit(
        emit,
        state.copyWith(
          guestControls: state.guestControls.copyWith(
            isVideoMuted: !event.enabled,
          ),
        ),
      );
      _logEvent('GUEST_VIDEO_TOGGLED', 'Enabled: ${event.enabled}');
    } catch (e) {
      add(ErrorOccurred('Failed to toggle video: $e'));
    }
  }

  Future<void> _onGuestAudioToggled(
    GuestAudioToggled event,
    Emitter<ViewerState> emit,
  ) async {
    try {
      await liveStreamService?.setMicEnabled(event.enabled);
      _safeEmit(
        emit,
        state.copyWith(
          guestControls: state.guestControls.copyWith(
            isAudioMuted: !event.enabled,
          ),
        ),
      );
      _logEvent('GUEST_AUDIO_TOGGLED', 'Enabled: ${event.enabled}');
    } catch (e) {
      add(ErrorOccurred('Failed to toggle audio: $e'));
    }
  }

  Future<void> _onModeSwitched(
    ModeSwitched event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(
        viewMode: event.mode,
        showRoleChangeToast: true,
        roleChangeMessage: _getModeChangeMessage(event.mode),
      ),
    );

    _logEvent('MODE_SWITCHED', 'New mode: ${event.mode}');

    Future.delayed(const Duration(seconds: 3), () {
      if (!_isClosing && !isClosed) {
        add(const RoleChangeToastDismissed());
      }
    });
  }

  String _getModeChangeMessage(ViewMode mode) {
    switch (mode) {
      case ViewMode.guest:
        return 'You are now a guest! You can participate in the stream.';
      case ViewMode.cohost:
        return 'You are now a co-host! You have host privileges.';
      case ViewMode.viewer:
        return 'You are in viewer mode.';
    }
  }

  // ============ EXISTING HANDLERS (UPDATED) ============

  Future<void> _onParticipantRoleChanged(
    ParticipantRoleChanged event,
    Emitter<ViewerState> emit,
  ) async {
    _logEvent('ROLE_CHANGED', 'New role: ${event.role}');

    // Determine view mode from role
    final ViewMode newMode = switch (event.role) {
      'guest' => ViewMode.guest,
      'cohost' => ViewMode.cohost,
      _ => ViewMode.viewer,
    };

    // Trigger role change service if available
    if (roleChangeService != null) {
      try {
        await roleChangeService!.safeRoleChange(event.role);
      } catch (e) {
        _logEvent('ROLE_CHANGE_SERVICE_ERROR', 'Error: $e');
      }
    }

    _safeEmit(
      emit,
      state.copyWith(
        currentRole: event.role,
        viewMode: newMode,
        showRoleChangeToast: true,
        roleChangeMessage: _getRoleChangeMessage(event.role),
        // Clear guest UUID if demoting
        activeGuestUuid: (event.role == 'audience' || event.role == 'viewer')
            ? null
            : state.activeGuestUuid,
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (!_isClosing && !isClosed) {
        add(const RoleChangeToastDismissed());
      }
    });
  }

  // ============ HELPER METHODS ============

  void _safeEmit(Emitter<ViewerState> emit, ViewerState newState) {
    if (!_isClosing && !isClosed) {
      emit(newState);
    }
  }

  String _getRoleChangeMessage(String role) {
    switch (role) {
      case 'guest':
        return 'You are now a guest! You can participate in the stream.';
      case 'cohost':
        return 'You are now a co-host! You have host privileges.';
      case 'audience':
        return 'You are back in the audience.';
      default:
        return 'Your role has been changed to $role.';
    }
  }

  // ============ EXISTING METHODS (PRESERVED) ============

  // [Preserving all existing methods: _setupSubscriptions, _cancelAllSubscriptions,
  // _onFollowToggled, _onCommentSent, _onLikePressed, _onSharePressed,
  // _onRequestToJoinPressed, _onChatArrived, _onGuestJoined, _onGiftArrived,
  // _onMyApprovalChanged, _onParticipantRemoved, _onErrorOccurred,
  // _onGiftsFetchRequested, _onGiftSendRequested, _onGiftSendSucceeded,
  // _onGiftBroadcastReceived, _onGiftOverlayDequeued]
  // These remain exactly as in your original code, just adding _safeEmit wrapper

  // ============ ENHANCED CLEANUP ============

  void _setupSubscriptions() {
    // Cancel any existing subscriptions first
    _cancelAllSubscriptions();

    // Setup new subscriptions with error handling
    _clockSub = repo.watchLiveClock().listen(
      (d) => add(_Ticked(d)),
      onError: (e) => _logEvent('CLOCK_ERROR', 'Error: $e'),
      cancelOnError: true,
    );

    _viewerSub = repo.watchViewerCount().listen(
      (c) {
        // Filter out invalid viewer counts (0 might be from empty events)
        if (c >= 0) {
          add(_ViewerCountUpdated(c));
        }
      },
      onError: (e) => _logEvent('VIEWER_ERROR', 'Error: $e'),
      cancelOnError: true,
    );

    _chatSub = repo.watchChat().listen(
      (m) => add(_ChatArrived(m)),
      onError: (e) => _logEvent('CHAT_ERROR', 'Error: $e'),
      cancelOnError: true,
    );

    _guestSub = repo.watchGuestJoins().listen(
      (n) => add(_GuestJoined(n)),
      onError: (e) => _logEvent('GUEST_ERROR', 'Error: $e'),
      cancelOnError: true,
    );

    _giftSub = repo.watchGifts().listen(
      (n) => add(_GiftArrived(n)),
      onError: (e) => _logEvent('GIFT_ERROR', 'Error: $e'),
      cancelOnError: true,
    );

    _pauseSub = repo.watchPause().listen(
      (p) => add(_PauseChanged(p)),
      onError: (e) => _logEvent('PAUSE_ERROR', 'Error: $e'),
      cancelOnError: true,
    );

    _endedSub = repo.watchEnded().listen(
      (_) => add(const _LiveEnded()),
      onError: (e) => _logEvent('ENDED_ERROR', 'Error: $e'),
      cancelOnError: true,
    );

    _approvalSub = repo.watchMyApproval().listen(
      (ok) => add(_MyApprovalChanged(ok)),
      onError: (e) => _logEvent('APPROVAL_ERROR', 'Error: $e'),
      cancelOnError: true,
    );

    _errorSub = repo.watchErrors().listen(
      (error) {
        if (error.isNotEmpty) {
          add(ErrorOccurred(error));
        }
      },
      onError: (e) => _logEvent('ERROR_STREAM_ERROR', 'Error: $e'),
      cancelOnError: true,
    );

    _roleChangeSub = repo.watchParticipantRoleChanges().listen(
      (role) => add(ParticipantRoleChanged(role)),
      onError: (e) => _logEvent('ROLE_CHANGE_ERROR', 'Error: $e'),
      cancelOnError: true,
    );

    _removalSub = repo.watchParticipantRemovals().listen(
      (reason) => add(ParticipantRemoved(reason)),
      onError: (e) => _logEvent('REMOVAL_ERROR', 'Error: $e'),
      cancelOnError: true,
    );

    if (repo is ViewerRepositoryImpl) {
      _activeGuestSub = (repo as ViewerRepositoryImpl)
          .watchActiveGuestUuid()
          .listen(
            (uuid) => add(_ActiveGuestUpdated(uuid)),
            onError: (e) => _logEvent('ACTIVE_GUEST_ERROR', 'Error: $e'),
            cancelOnError: true,
          );
    }

    _giftBroadcastSub = repo.watchGiftBroadcasts().listen(
      (b) => add(GiftBroadcastReceived(b)),
      onError: (e) => _logEvent('GIFT_BROADCAST_ERROR', 'Error: $e'),
      cancelOnError: true,
    );
  }

  void _cancelAllSubscriptions() {
    _clockSub?.cancel();
    _viewerSub?.cancel();
    _chatSub?.cancel();
    _guestSub?.cancel();
    _giftSub?.cancel();
    _pauseSub?.cancel();
    _endedSub?.cancel();
    _approvalSub?.cancel();
    _errorSub?.cancel();
    _roleChangeSub?.cancel();
    _removalSub?.cancel();
    _activeGuestSub?.cancel();
    _giftBroadcastSub?.cancel();

    _clockSub = null;
    _viewerSub = null;
    _chatSub = null;
    _guestSub = null;
    _giftSub = null;
    _pauseSub = null;
    _endedSub = null;
    _approvalSub = null;
    _errorSub = null;
    _roleChangeSub = null;
    _removalSub = null;
    _activeGuestSub = null;
    _giftBroadcastSub = null;
  }

  Future<void> _onFollowToggled(
    FollowToggled e,
    Emitter<ViewerState> emit,
  ) async {
    try {
      final newState = await repo.toggleFollow(state.host?.isFollowed ?? false);
      emit(state.copyWith(host: state.host?.copyWith(isFollowed: newState)));
      _logEvent('FOLLOW_TOGGLED', 'New state: $newState');
    } catch (e) {
      _logEvent('FOLLOW_FAILED', 'Error: $e');
    }
  }

  Future<void> _onCommentSent(CommentSent e, Emitter<ViewerState> emit) async {
    final text = e.text.trim();
    if (text.isEmpty) return;

    try {
      await repo.sendComment(text);
      _logEvent('COMMENT_SENT', 'Text: $text');
    } catch (e) {
      _logEvent('COMMENT_FAILED', 'Error: $e');
    }
  }

  Future<void> _onLikePressed(LikePressed e, Emitter<ViewerState> emit) async {
    try {
      final count = await repo.like();
      emit(state.copyWith(likes: count));
      _logEvent('LIKE_PRESSED', 'Count: $count');
    } catch (e) {
      _logEvent('LIKE_FAILED', 'Error: $e');
    }
  }

  Future<void> _onSharePressed(
    SharePressed e,
    Emitter<ViewerState> emit,
  ) async {
    try {
      final count = await repo.share();
      emit(state.copyWith(shares: count));
      _logEvent('SHARE_PRESSED', 'Count: $count');
    } catch (e) {
      _logEvent('SHARE_FAILED', 'Error: $e');
    }
  }

  Future<void> _onRequestToJoinPressed(
    RequestToJoinPressed e,
    Emitter<ViewerState> emit,
  ) async {
    try {
      await repo.requestToJoin();
      emit(state.copyWith(joinRequested: true, awaitingApproval: true));
      _logEvent('JOIN_REQUESTED', 'Request sent');
    } catch (e) {
      emit(state.copyWith(joinRequested: false, awaitingApproval: false));
      _logEvent('JOIN_REQUEST_FAILED', 'Error: $e');
    }
  }

  // Add these corrected methods to viewer_bloc.dart

  Future<void> _onChatArrived(
    _ChatArrived event,
    Emitter<ViewerState> emit,
  ) async {
    // Keep only last 200 chat messages
    final updatedChat = [...state.chat];
    updatedChat.add(event.message);
    if (updatedChat.length > 200) {
      updatedChat.removeAt(0);
    }

    _safeEmit(emit, state.copyWith(chat: updatedChat));
  }

  Future<void> _onGuestJoined(
    _GuestJoined event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(emit, state.copyWith(guest: event.notice, showGuestBanner: true));

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isClosing && !isClosed) {
        add(const GuestBannerDismissed());
      }
    });
  }

  Future<void> _onGiftArrived(
    _GiftArrived event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(emit, state.copyWith(gift: event.notice, showGiftToast: true));

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isClosing && !isClosed) {
        add(const GiftToastDismissed());
      }
    });
  }

  Future<void> _onMyApprovalChanged(
    _MyApprovalChanged event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(
        awaitingApproval: !event.accepted,
        joinRequested: event.accepted,
      ),
    );

    _logEvent('APPROVAL_CHANGED', 'Approved: ${event.accepted}');
  }

  Future<void> _onParticipantRemoved(
    ParticipantRemoved event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(
        showRemovalOverlay: true,
        removalReason: event.reason,
        shouldNavigateBack: true,
      ),
    );

    _logEvent('REMOVED', 'Reason: ${event.reason}');

    // Auto-navigate after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isClosing && !isClosed) {
        add(const NavigateBackRequested());
      }
    });
  }

  Future<void> _onErrorOccurred(
    ErrorOccurred event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(
        errorMessage: event.message.isNotEmpty ? event.message : null,
      ),
    );

    if (event.message.isNotEmpty) {
      _logEvent('ERROR', event.message);
    }
  }

  Future<void> _onGiftsFetchRequested(
    GiftsFetchRequested event,
    Emitter<ViewerState> emit,
  ) async {
    try {
      final (gifts, version) = await repo.fetchGiftCatalog();
      _safeEmit(
        emit,
        state.copyWith(giftCatalog: gifts, giftCatalogVersion: version),
      );
      _logEvent('GIFTS_FETCHED', 'Loaded ${gifts.length} gifts');
    } catch (e) {
      _safeEmit(emit, state.copyWith(errorMessage: 'Failed to load gifts: $e'));
      _logEvent('GIFTS_FETCH_FAILED', 'Error: $e');
    }
  }

  Future<void> _onGiftSendRequested(
    GiftSendRequested event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(isSendingGift: true, sendErrorMessage: null),
    );

    try {
      final result = await repo.sendGift(
        giftCode: event.code,
        toUserUuid: event.toUserUuid,
        livestreamId: event.livestreamId,
        quantity: event.quantity,
      );

      add(GiftSendSucceeded(result));
    } catch (e) {
      add(GiftSendFailed(e.toString()));
    }
  }

  Future<void> _onGiftSendSucceeded(
    GiftSendSucceeded event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(
        isSendingGift: false,
        walletBalanceCoins: event.result.newBalanceCoins,
        sendErrorMessage: null,
      ),
    );

    _logEvent(
      'GIFT_SENT',
      'Gift sent: ${event.result.serverTxnId}, New balance: ${event.result.newBalanceCoins}',
    );
  }

  Future<void> _onGiftBroadcastReceived(
    GiftBroadcastReceived event,
    Emitter<ViewerState> emit,
  ) async {
    // Add gift to queue for display - you'll need to implement this in state
    _safeEmit(
      emit,
      state.copyWith(
        gift: GiftNotice(
          from: event.broadcast.senderDisplayName,
          giftName: event.broadcast.giftCode,
          coins: event.broadcast.coinsSpent,
        ),
        showGiftToast: true,
      ),
    );

    _logEvent('GIFT_BROADCAST', 'Received: ${event.broadcast.giftCode}');
  }

  Future<void> _onGiftOverlayDequeued(
    GiftOverlayDequeued event,
    Emitter<ViewerState> emit,
  ) async {
    // Clear gift toast
    _safeEmit(emit, state.copyWith(showGiftToast: false, gift: null));
  }

  @override
  Future<void> close() {
    _logEvent('BLOC_CLOSING', 'Starting enhanced close');
    _isClosing = true;

    // Cancel all service subscriptions
    _networkStatusSub?.cancel();
    _connectionStatsSub?.cancel();
    _reconnectionSub?.cancel();
    _roleChangeResultSub?.cancel();
    _hostQualitySub?.cancel();
    _selfQualitySub?.cancel();
    _guestQualitySub?.cancel();
    _connectionStateSub?.cancel();

    // Stop services
    networkMonitorService?.stopMonitoring();
    networkMonitorService?.dispose();
    reconnectionService?.stopMonitoring();
    reconnectionService?.dispose();

    // Existing cleanup
    _cancelAllSubscriptions();

    if (repo is ViewerRepositoryImpl) {
      try {
        (repo as ViewerRepositoryImpl).cancelClock();
      } catch (e) {
        _logEvent('CLOCK_CANCEL_ERROR', 'Error: $e');
      }
    }

    try {
      repo.dispose();
      _logEvent('REPO_DISPOSED', 'Repository disposed');
    } catch (e) {
      _logEvent('REPO_DISPOSE_ERROR', 'Error: $e');
    }

    _logEvent('BLOC_CLOSED', 'Enhanced bloc closed');

    if (_eventLog.isNotEmpty) {
      debugPrint('📋 FINAL EVENT HISTORY (last ${_eventLog.length}):');
      for (final event in _eventLog.take(10)) {
        debugPrint('   $event');
      }
    }

    return super.close();
  }
}


//_onChatArrived, _onGuestJoined, _onGiftArrived,
  // _onMyApprovalChanged, _onParticipantRemoved, _onErrorOccurred,
  // _onGiftsFetchRequested, _onGiftSendRequested, _onGiftSendSucceeded,
  // _onGiftBroadcastReceived, _onGiftOverlayDequeued asre missing
