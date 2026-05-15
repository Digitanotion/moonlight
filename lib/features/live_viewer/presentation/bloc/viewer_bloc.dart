// lib/features/live_viewer/presentation/bloc/viewer_bloc.dart
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
import 'package:moonlight/features/live_viewer/presentation/services/stream_health_service.dart';

part 'viewer_event.dart';
part 'viewer_state.dart';

class ViewerBloc extends Bloc<ViewerEvent, ViewerState> {
  final ViewerRepository repo;
  final LiveStreamService? liveStreamService;
  final AgoraViewerService? agoraViewerService;
  final NetworkMonitorService? networkMonitorService;
  final ReconnectionService? reconnectionService;
  final RoleChangeService? roleChangeService;

  // Core stream subscriptions
  StreamSubscription? _clockSub, _viewerSub, _chatSub, _guestSub, _giftSub;
  StreamSubscription? _pauseSub, _endedSub, _approvalSub;
  StreamSubscription? _errorSub, _roleChangeSub, _removalSub;
  StreamSubscription<String?>? _activeGuestSub;
  StreamSubscription<GiftBroadcast>? _giftBroadcastSub;

  // Service subscriptions
  StreamSubscription<NetworkStatus>? _networkStatusSub;
  StreamSubscription<ConnectionStats>? _connectionStatsSub;
  StreamSubscription<ReconnectionStatus>? _reconnectionSub;
  StreamSubscription<RoleChangeResult>? _roleChangeResultSub;
  StreamSubscription<NetworkQuality>? _hostQualitySub;
  StreamSubscription<NetworkQuality>? _selfQualitySub;
  StreamSubscription<NetworkQuality>? _guestQualitySub;
  StreamSubscription<ConnectionState>? _connectionStateSub;

  // Health service
  StreamHealthService? _streamHealthService;
  StreamSubscription<StreamHealthResult>? _healthSub;

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
    _logEvent('BLOC_CREATED', 'Bloc created');

    on<ViewerStarted>(_onStarted);

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
    on<FollowToggled>(_onFollowToggled);
    on<CommentSent>(_onCommentSent);
    on<LikePressed>(_onLikePressed);
    on<SharePressed>(_onSharePressed);
    on<RequestToJoinPressed>(_onRequestToJoinPressed);
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

    // Gifts
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

    // Network
    on<NetworkQualityUpdated>(_onNetworkQualityUpdated);
    on<ConnectionStatsUpdated>(
      (e, emit) =>
          _logEvent('CONNECTION_STATS', 'Updated: ${e.stats.bitrate}kbps'),
    );
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

    // Mode
    on<ModeSwitched>(_onModeSwitched);
    on<NetworkStatusVisibilityToggled>(
      (e, emit) =>
          _safeEmit(emit, state.copyWith(showNetworkStatus: e.visible)),
    );

    // ── Stream health ──────────────────────────────────────────
    on<StreamWentOffline>(_onStreamWentOffline);
    on<StreamBecameUnstable>(_onStreamBecameUnstable);
    on<StreamRecovered>(_onStreamRecovered);
    on<PremiumAccessRequired>(_onPremiumAccessRequired);
    on<PremiumAccessGranted>(_onPremiumAccessGranted);
    on<_PremiumCancelledByHost>(_onPremiumCancelledByHost);
  }

  // ── Logging ───────────────────────────────────────────────────────────────

  void _logEvent(String type, String message) {
    final entry = '[${DateTime.now()}] $type: $message';
    _eventLog.add(entry);
    if (_eventLog.length > 100) _eventLog.removeAt(0);
    debugPrint('🔵 BLOC: $entry');
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> _onStarted(
    ViewerStarted event,
    Emitter<ViewerState> emit,
  ) async {
    if (_isStarted) {
      _logEvent('START_IGNORED', 'Already started');
      return;
    }
    _isStarted = true;
    _logEvent('STARTING', 'Viewer started');

    _safeEmit(emit, state.copyWith(status: ViewerStatus.loading));

    try {
      final host = await repo.fetchHostInfo();
      _logEvent('HOST_FETCHED', 'Host: ${host.name}');

      int? walletBalance;
      try {
        walletBalance = await repo.fetchWalletBalance();
        _logEvent('WALLET_FETCHED', 'Balance: $walletBalance');
      } catch (e) {
        _logEvent('WALLET_FAILED', 'Error: $e');
      }

      _safeEmit(
        emit,
        state.copyWith(
          status: ViewerStatus.active,
          host: host,
          walletBalanceCoins: walletBalance,
          joinRequested: true,
          awaitingApproval: false,
        ),
      );
      _logEvent('STATE_ACTIVE', 'Ready');

      _setupSubscriptions();
      _startEnhancedServices();
      _startHealthService(); // ← health polling starts here
      _logEvent('SERVICES_STARTED', 'All services active');
    } catch (e, stack) {
      _logEvent('START_FAILED', 'Error: $e');
      debugPrint('Stack: $stack');
      _safeEmit(
        emit,
        state.copyWith(
          status: ViewerStatus.active,
          errorMessage: 'Failed to start: $e',
        ),
      );
    }
  }

  // ── Health service ────────────────────────────────────────────────────────

  void _startHealthService() {
    if (repo is! ViewerRepositoryImpl) return;
    final implRepo = repo as ViewerRepositoryImpl;

    _streamHealthService = StreamHealthService(
      http: implRepo.http,
      livestreamUuid: implRepo.livestreamParam,
      pollInterval: const Duration(seconds: 12),
    );

    _healthSub = _streamHealthService!.stream.listen((result) {
      if (_isClosing || isClosed) return;
      switch (result.status) {
        case StreamHealthStatus.offline:
          add(StreamWentOffline(result.message ?? 'Stream has ended.'));
        case StreamHealthStatus.unstable:
          add(
            StreamBecameUnstable(
              result.message ??
                  'Stream is unstable — trying to reach host network…',
            ),
          );
        case StreamHealthStatus.online:
          if (state.isStreamUnstable) add(const StreamRecovered());
          if (state.requiresPremiumPayment)
            add(const _PremiumCancelledByHost());
        case StreamHealthStatus.premiumRequired:
          add(PremiumAccessRequired(result.entryFeeCoins ?? 0));
        case StreamHealthStatus.unknown:
          break;
      }
    }, onError: (e) => _logEvent('HEALTH_ERROR', 'Error: $e'));

    _streamHealthService!.start();
    _logEvent('HEALTH_SERVICE', 'Polling every 12s');
  }

  // ── Stream health handlers ────────────────────────────────────────────────

  Future<void> _onStreamWentOffline(
    StreamWentOffline event,
    Emitter<ViewerState> emit,
  ) async {
    _logEvent('STREAM_OFFLINE', event.message);
    _streamHealthService?.stop(); // No point polling a dead stream
    _safeEmit(emit, state.copyWith(isEnded: true, errorMessage: event.message));
  }

  Future<void> _onStreamBecameUnstable(
    StreamBecameUnstable event,
    Emitter<ViewerState> emit,
  ) async {
    _logEvent('STREAM_UNSTABLE', event.message);
    _safeEmit(
      emit,
      state.copyWith(
        isStreamUnstable: true,
        streamUnstableMessage: event.message,
      ),
    );
  }

  Future<void> _onStreamRecovered(
    StreamRecovered event,
    Emitter<ViewerState> emit,
  ) async {
    _logEvent('STREAM_RECOVERED', 'Back online');
    _safeEmit(
      emit,
      state.copyWith(isStreamUnstable: false, streamUnstableMessage: null),
    );
  }

  Future<void> _onPremiumAccessRequired(
    PremiumAccessRequired event,
    Emitter<ViewerState> emit,
  ) async {
    _logEvent('PREMIUM_REQUIRED', 'Fee: ${event.entryFeeCoins} coins');
    try {
      // Mute ALL incoming remote audio — stops viewer hearing host/guests.
      await agoraViewerService?.muteAllRemoteAudio(true);
      // Also mute the viewer's own outgoing streams (they are audience).
      await agoraViewerService?.setMicEnabled(false);
      await agoraViewerService?.setCamEnabled(false);
    } catch (_) {}
    _safeEmit(
      emit,
      state.copyWith(
        requiresPremiumPayment: true,
        premiumEntryFeeCoins: event.entryFeeCoins,
      ),
    );
  }

  Future<void> _onPremiumAccessGranted(
    PremiumAccessGranted event,
    Emitter<ViewerState> emit,
  ) async {
    _logEvent('PREMIUM_GRANTED', 'Access restored');
    _streamHealthService?.onPremiumGranted();
    try {
      // Restore incoming remote audio so viewer can hear the stream again.
      await agoraViewerService?.muteAllRemoteAudio(false);
    } catch (_) {}
    _safeEmit(
      emit,
      state.copyWith(requiresPremiumPayment: false, premiumEntryFeeCoins: null),
    );
  }

  // Fired when the health service detects host cancelled premium mid-session.
  // Does NOT call onPremiumGranted() on the service — the service already
  // reset _premiumAccessConfirmed so future re-enables are detected.
  Future<void> _onPremiumCancelledByHost(
    _PremiumCancelledByHost event,
    Emitter<ViewerState> emit,
  ) async {
    _logEvent(
      'PREMIUM_CANCELLED_BY_HOST',
      'Host cancelled premium — clearing paywall',
    );
    try {
      // Restore incoming remote audio — host made stream free again.
      await agoraViewerService?.muteAllRemoteAudio(false);
    } catch (_) {}
    _safeEmit(
      emit,
      state.copyWith(requiresPremiumPayment: false, premiumEntryFeeCoins: null),
    );
  }

  // ── Network quality ───────────────────────────────────────────────────────

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
  }

  // ── Reconnection ──────────────────────────────────────────────────────────

  Future<void> _onConnectionLost(
    ConnectionLost event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(
      emit,
      state.copyWith(
        isReconnecting: true,
        reconnectAttempts: 0,
        reconnectMessage: 'Connection lost. Reconnecting…',
        showReconnectOverlay: true,
        networkStatus: state.networkStatus.copyWith(
          isReconnecting: true,
          lastDisconnection: event.timestamp,
        ),
      ),
    );
    _logEvent('CONNECTION_LOST', event.reason);
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
        reconnectMessage: 'Attempting to reconnect…',
        showReconnectOverlay: true,
      ),
    );
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
        reconnectMessage: 'Reconnected!',
        showReconnectOverlay: false,
        networkStatus: state.networkStatus.copyWith(
          isReconnecting: false,
          reconnectAttempts: event.attempts,
        ),
      ),
    );
    _logEvent('RECONNECTION_SUCCEEDED', 'Attempts: ${event.attempts}');
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isClosing && !isClosed) add(const ErrorOccurred(''));
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
    _logEvent('RECONNECTION_FAILED', 'Error: ${event.error}');
  }

  // ── Guest controls ────────────────────────────────────────────────────────

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
    } catch (e) {
      add(ErrorOccurred('Failed to toggle audio: $e'));
    }
  }

  // ── Mode switching ────────────────────────────────────────────────────────

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
      if (!_isClosing && !isClosed) add(const RoleChangeToastDismissed());
    });
  }

  String _getModeChangeMessage(ViewMode mode) => switch (mode) {
    ViewMode.guest => 'You are now a guest! You can participate.',
    ViewMode.cohost => 'You are now a co-host!',
    ViewMode.viewer => 'You are in viewer mode.',
  };

  // ── Role change ───────────────────────────────────────────────────────────

  Future<void> _onParticipantRoleChanged(
    ParticipantRoleChanged event,
    Emitter<ViewerState> emit,
  ) async {
    _logEvent('ROLE_CHANGED', 'New role: ${event.role}');

    final ViewMode newMode = switch (event.role) {
      'guest' => ViewMode.guest,
      'cohost' => ViewMode.cohost,
      _ => ViewMode.viewer,
    };

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
        activeGuestUuid: (event.role == 'audience' || event.role == 'viewer')
            ? null
            : state.activeGuestUuid,
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (!_isClosing && !isClosed) add(const RoleChangeToastDismissed());
    });
  }

  String _getRoleChangeMessage(String role) => switch (role) {
    'guest' => 'You are now a guest! You can participate.',
    'cohost' => 'You are now a co-host!',
    'audience' => 'You are back in the audience.',
    _ => 'Your role has changed to $role.',
  };

  // ── Helper ────────────────────────────────────────────────────────────────

  void _safeEmit(Emitter<ViewerState> emit, ViewerState newState) {
    if (!_isClosing && !isClosed) emit(newState);
  }

  // ── Enhanced services ─────────────────────────────────────────────────────

  void _startEnhancedServices() {
    networkMonitorService?.startMonitoring();
    reconnectionService?.startMonitoring();
    _setupServiceSubscriptions();
  }

  void _setupServiceSubscriptions() {
    if (networkMonitorService != null) {
      _networkStatusSub = networkMonitorService!.watchNetworkStatus().listen(
        (s) => add(
          NetworkQualityUpdated(
            selfQuality: s.selfQuality,
            hostQuality: s.hostQuality,
            guestQuality: s.guestQuality,
          ),
        ),
        onError: (e) => _logEvent('NETWORK_STATUS_ERROR', '$e'),
      );
      _connectionStatsSub = networkMonitorService!
          .watchConnectionStats()
          .listen(
            (s) => add(ConnectionStatsUpdated(s)),
            onError: (e) => _logEvent('CONNECTION_STATS_ERROR', '$e'),
          );
      networkMonitorService!.watchNetworkIssues().listen(
        (issue) => add(ErrorOccurred('Network: $issue')),
        onError: (e) => _logEvent('NETWORK_ISSUE_ERROR', '$e'),
      );
    }

    if (reconnectionService != null) {
      _reconnectionSub = reconnectionService!.watchReconnection().listen((s) {
        if (s.isActive) {
          add(ReconnectionStarted());
        } else if (s.isSuccessful) {
          add(ReconnectionSucceeded(s.attempt));
        } else if (s.isFailed || s.gaveUp) {
          add(
            ReconnectionFailed(
              error: s.message ?? 'Unknown error',
              attempts: s.attempt,
            ),
          );
        }
      }, onError: (e) => _logEvent('RECONNECTION_ERROR', '$e'));
    }

    if (roleChangeService != null) {
      _roleChangeResultSub = roleChangeService!.watchRoleChanges().listen((
        result,
      ) {
        if (result.state == RoleChangeState.promoted) {
          add(ModeSwitched(ViewMode.guest));
        } else if (result.state == RoleChangeState.demoted) {
          add(ModeSwitched(ViewMode.viewer));
        } else if (result.state == RoleChangeState.failed) {
          add(ErrorOccurred(result.error ?? 'Role change failed'));
        }
      }, onError: (e) => _logEvent('ROLE_CHANGE_ERROR', '$e'));

      roleChangeService!.guestAudioMuted.addListener(() {
        add(GuestControlsUpdated(roleChangeService!.getGuestControlsState()));
      });
      roleChangeService!.guestVideoMuted.addListener(() {
        add(GuestControlsUpdated(roleChangeService!.getGuestControlsState()));
      });
    }

    if (liveStreamService != null) {
      _hostQualitySub = liveStreamService!.watchHostNetworkQuality().listen(
        (q) => add(
          NetworkQualityUpdated(
            selfQuality: state.networkStatus.selfQuality,
            hostQuality: q,
            guestQuality: state.networkStatus.guestQuality,
          ),
        ),
        onError: (e) => _logEvent('HOST_QUALITY_ERROR', '$e'),
      );

      _selfQualitySub = liveStreamService!.watchSelfNetworkQuality().listen(
        (q) => add(
          NetworkQualityUpdated(
            selfQuality: q,
            hostQuality: state.networkStatus.hostQuality,
            guestQuality: state.networkStatus.guestQuality,
          ),
        ),
        onError: (e) => _logEvent('SELF_QUALITY_ERROR', '$e'),
      );

      final guestStream = liveStreamService!.watchGuestNetworkQuality();
      if (guestStream != null) {
        _guestQualitySub = guestStream.listen(
          (q) => add(
            NetworkQualityUpdated(
              selfQuality: state.networkStatus.selfQuality,
              hostQuality: state.networkStatus.hostQuality,
              guestQuality: q,
            ),
          ),
          onError: (e) => _logEvent('GUEST_QUALITY_ERROR', '$e'),
        );
      }

      _connectionStateSub = liveStreamService!.watchConnectionState().listen((
        cs,
      ) {
        if (cs == ConnectionState.disconnected) {
          add(
            ConnectionLost(
              timestamp: DateTime.now(),
              reason: 'Connection lost',
            ),
          );
        }
      }, onError: (e) => _logEvent('CONNECTION_STATE_ERROR', '$e'));
    }
  }

  // ── Core subscriptions ────────────────────────────────────────────────────

  void _setupSubscriptions() {
    _cancelAllSubscriptions();

    _clockSub = repo.watchLiveClock().listen(
      (d) => add(_Ticked(d)),
      onError: (e) => _logEvent('CLOCK_ERROR', '$e'),
      cancelOnError: true,
    );

    _viewerSub = repo.watchViewerCount().listen(
      (c) {
        if (c >= 0) add(_ViewerCountUpdated(c));
      },
      onError: (e) => _logEvent('VIEWER_ERROR', '$e'),
      cancelOnError: true,
    );

    _chatSub = repo.watchChat().listen(
      (m) => add(_ChatArrived(m)),
      onError: (e) => _logEvent('CHAT_ERROR', '$e'),
      cancelOnError: true,
    );

    _guestSub = repo.watchGuestJoins().listen(
      (n) => add(_GuestJoined(n)),
      onError: (e) => _logEvent('GUEST_ERROR', '$e'),
      cancelOnError: true,
    );

    _giftSub = repo.watchGifts().listen(
      (n) => add(_GiftArrived(n)),
      onError: (e) => _logEvent('GIFT_ERROR', '$e'),
      cancelOnError: true,
    );

    _pauseSub = repo.watchPause().listen(
      (p) => add(_PauseChanged(p)),
      onError: (e) => _logEvent('PAUSE_ERROR', '$e'),
      cancelOnError: true,
    );

    _endedSub = repo.watchEnded().listen(
      (_) => add(const _LiveEnded()),
      onError: (e) => _logEvent('ENDED_ERROR', '$e'),
      cancelOnError: true,
    );

    _approvalSub = repo.watchMyApproval().listen(
      (ok) => add(_MyApprovalChanged(ok)),
      onError: (e) => _logEvent('APPROVAL_ERROR', '$e'),
      cancelOnError: true,
    );

    _errorSub = repo.watchErrors().listen(
      (error) {
        if (error.isNotEmpty) add(ErrorOccurred(error));
      },
      onError: (e) => _logEvent('ERROR_STREAM_ERROR', '$e'),
      cancelOnError: true,
    );

    _roleChangeSub = repo.watchParticipantRoleChanges().listen(
      (role) => add(ParticipantRoleChanged(role)),
      onError: (e) => _logEvent('ROLE_CHANGE_ERROR', '$e'),
      cancelOnError: true,
    );

    _removalSub = repo.watchParticipantRemovals().listen(
      (reason) => add(ParticipantRemoved(reason)),
      onError: (e) => _logEvent('REMOVAL_ERROR', '$e'),
      cancelOnError: true,
    );

    if (repo is ViewerRepositoryImpl) {
      _activeGuestSub = (repo as ViewerRepositoryImpl)
          .watchActiveGuestUuid()
          .listen(
            (uuid) => add(_ActiveGuestUpdated(uuid)),
            onError: (e) => _logEvent('ACTIVE_GUEST_ERROR', '$e'),
            cancelOnError: true,
          );
    }

    _giftBroadcastSub = repo.watchGiftBroadcasts().listen(
      (b) => add(GiftBroadcastReceived(b)),
      onError: (e) => _logEvent('GIFT_BROADCAST_ERROR', '$e'),
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
    _clockSub = _viewerSub = _chatSub = _guestSub = _giftSub = null;
    _pauseSub = _endedSub = _approvalSub = _errorSub = null;
    _roleChangeSub = _removalSub = null;
    _activeGuestSub = null;
    _giftBroadcastSub = null;
  }

  // ── User action handlers ──────────────────────────────────────────────────

  Future<void> _onFollowToggled(
    FollowToggled e,
    Emitter<ViewerState> emit,
  ) async {
    try {
      final newState = await repo.toggleFollow(state.host?.isFollowed ?? false);
      _safeEmit(
        emit,
        state.copyWith(host: state.host?.copyWith(isFollowed: newState)),
      );
    } catch (e) {
      _logEvent('FOLLOW_FAILED', '$e');
    }
  }

  Future<void> _onCommentSent(CommentSent e, Emitter<ViewerState> emit) async {
    final text = e.text.trim();
    if (text.isEmpty) return;
    try {
      await repo.sendComment(text);
    } catch (e) {
      _logEvent('COMMENT_FAILED', '$e');
    }
  }

  Future<void> _onLikePressed(LikePressed e, Emitter<ViewerState> emit) async {
    try {
      final count = await repo.like();
      _safeEmit(emit, state.copyWith(likes: count));
    } catch (e) {
      _logEvent('LIKE_FAILED', '$e');
    }
  }

  Future<void> _onSharePressed(
    SharePressed e,
    Emitter<ViewerState> emit,
  ) async {
    try {
      final count = await repo.share();
      _safeEmit(emit, state.copyWith(shares: count));
    } catch (e) {
      _logEvent('SHARE_FAILED', '$e');
    }
  }

  Future<void> _onRequestToJoinPressed(
    RequestToJoinPressed e,
    Emitter<ViewerState> emit,
  ) async {
    try {
      await repo.requestToJoin();
      _safeEmit(
        emit,
        state.copyWith(joinRequested: true, awaitingApproval: true),
      );
    } catch (e) {
      _safeEmit(
        emit,
        state.copyWith(joinRequested: false, awaitingApproval: false),
      );
      _logEvent('JOIN_REQUEST_FAILED', '$e');
    }
  }

  Future<void> _onChatArrived(
    _ChatArrived event,
    Emitter<ViewerState> emit,
  ) async {
    final updated = [...state.chat, event.message];
    if (updated.length > 200) updated.removeAt(0);
    _safeEmit(emit, state.copyWith(chat: updated));
  }

  Future<void> _onGuestJoined(
    _GuestJoined event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(emit, state.copyWith(guest: event.notice, showGuestBanner: true));
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isClosing && !isClosed) add(const GuestBannerDismissed());
    });
  }

  Future<void> _onGiftArrived(
    _GiftArrived event,
    Emitter<ViewerState> emit,
  ) async {
    _safeEmit(emit, state.copyWith(gift: event.notice, showGiftToast: true));
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isClosing && !isClosed) add(const GiftToastDismissed());
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
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isClosing && !isClosed) add(const NavigateBackRequested());
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
    if (event.message.isNotEmpty) _logEvent('ERROR', event.message);
  }

  // ── Gift handlers ─────────────────────────────────────────────────────────

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
      'Txn: ${event.result.serverTxnId}, Balance: ${event.result.newBalanceCoins}',
    );
  }

  Future<void> _onGiftBroadcastReceived(
    GiftBroadcastReceived event,
    Emitter<ViewerState> emit,
  ) async {
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
    _safeEmit(emit, state.copyWith(showGiftToast: false, gift: null));
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    _logEvent('BLOC_CLOSING', 'Starting close');
    _isClosing = true;

    // Health service
    _healthSub?.cancel();
    _streamHealthService?.dispose();

    // Service subscriptions
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

    _cancelAllSubscriptions();

    if (repo is ViewerRepositoryImpl) {
      try {
        (repo as ViewerRepositoryImpl).cancelClock();
      } catch (e) {
        _logEvent('CLOCK_CANCEL_ERROR', '$e');
      }
    }

    try {
      repo.dispose();
    } catch (e) {
      _logEvent('REPO_DISPOSE_ERROR', '$e');
    }

    _logEvent('BLOC_CLOSED', 'Done');
    return super.close();
  }
}
