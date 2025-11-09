import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';
import '../../domain/entities.dart';
import '../../domain/repositories/viewer_repository.dart';

part 'viewer_event.dart';
part 'viewer_state.dart';

class ViewerBloc extends Bloc<ViewerEvent, ViewerState> {
  final ViewerRepository repo;
  StreamSubscription? _clockSub, _viewerSub, _chatSub, _guestSub, _giftSub;
  StreamSubscription? _pauseSub, _endedSub, _approvalSub;
  StreamSubscription? _errorSub, _roleChangeSub, _removalSub;
  StreamSubscription<String?>? _activeGuestSub;
  StreamSubscription<GiftBroadcast>? _giftBroadcastSub;

  ViewerBloc(this.repo) : super(ViewerState.initial()) {
    on<ViewerStarted>(_onStarted);
    on<_Ticked>((e, emit) => emit(state.copyWith(elapsed: e.elapsed)));
    on<_ViewerCountUpdated>(
      (e, emit) => emit(state.copyWith(viewers: e.count)),
    );
    on<_ChatArrived>((e, emit) {
      final list = List<ChatMessage>.from(state.chat)..add(e.message);
      emit(state.copyWith(chat: list));
    });
    on<_GuestJoined>((e, emit) {
      emit(state.copyWith(guest: e.notice, showGuestBanner: true));
      _autoHide(() => add(const GuestBannerDismissed()));
    });
    on<_GiftArrived>((e, emit) {
      emit(state.copyWith(gift: e.notice, showGiftToast: true));
      _autoHide(() => add(const GiftToastDismissed()));
    });
    on<GuestBannerDismissed>(
      (e, emit) => emit(state.copyWith(showGuestBanner: false)),
    );
    on<GiftToastDismissed>(
      (e, emit) => emit(state.copyWith(showGiftToast: false)),
    );

    on<FollowToggled>(_onFollowToggled);
    on<CommentSent>(_onCommentSent);
    on<LikePressed>(_onLikePressed);
    on<SharePressed>(_onSharePressed);
    on<RequestToJoinPressed>(_onRequestToJoinPressed);
    on<ChatVisibilityToggled>(
      (e, emit) => emit(state.copyWith(showChatUI: !state.showChatUI)),
    );
    on<ChatShowRequested>((e, emit) => emit(state.copyWith(showChatUI: true)));
    on<ChatHideRequested>((e, emit) => emit(state.copyWith(showChatUI: false)));
    on<_PauseChanged>((e, emit) => emit(state.copyWith(isPaused: e.paused)));
    on<_LiveEnded>((e, emit) => emit(state.copyWith(isEnded: true)));
    on<_MyApprovalChanged>((e, emit) {
      if (e.accepted) {
        emit(state.copyWith(awaitingApproval: false));
      } else {
        emit(state.copyWith(awaitingApproval: false, joinRequested: false));
      }
    });

    // ✅ ADD THESE NEW EVENT HANDLERS
    on<ErrorOccurred>((e, emit) {
      emit(state.copyWith(errorMessage: e.message));
      Future.delayed(const Duration(seconds: 5), () {
        add(const ErrorOccurred(''));
      });
    });

    on<ParticipantRoleChanged>((e, emit) {
      debugPrint('🎯 Viewer role changed to: ${e.role}');
      emit(
        state.copyWith(
          currentRole: e.role,
          showRoleChangeToast: true,
          roleChangeMessage: _getRoleChangeMessage(e.role),
        ),
      );
      _autoHide(() => add(const RoleChangeToastDismissed()));
    });

    on<ParticipantRemoved>((e, emit) {
      debugPrint('🎯 Viewer removed: ${e.reason}');
      emit(
        state.copyWith(
          isRemoved: true,
          removalReason: e.reason,
          errorMessage: _getRemovalMessage(e.reason),
          showRemovalOverlay: true,
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        add(const NavigateBackRequested());
      });
    });

    on<RoleChangeToastDismissed>(
      (e, emit) => emit(state.copyWith(showRoleChangeToast: false)),
    );
    on<NavigateBackRequested>(
      (e, emit) => emit(state.copyWith(shouldNavigateBack: true)),
    );
    on<_ActiveGuestUpdated>(
      (e, emit) => emit(state.copyWith(activeGuestUuid: e.uuid)),
    );
    on<GiftSheetRequested>((e, emit) {
      emit(state.copyWith(showGiftSheet: true));
      add(const GiftsFetchRequested());
    });
    on<GiftSheetClosed>((e, emit) {
      emit(state.copyWith(showGiftSheet: false, sendErrorMessage: null));
    });

    // === GIFTS: fetch catalog
    on<GiftsFetchRequested>((e, emit) async {
      final (items, version) = await repo.fetchGiftCatalog();
      emit(state.copyWith(giftCatalog: items, giftCatalogVersion: version));
    });

    // === GIFTS: send flow
    on<GiftSendRequested>((e, emit) async {
      emit(state.copyWith(isSendingGift: true, sendErrorMessage: null));
      try {
        final result = await repo.sendGift(
          giftCode: e.code,
          toUserUuid: e.toUserUuid,
          livestreamId: e.livestreamId,
          quantity: e.quantity,
        );
        add(GiftSendSucceeded(result));
      } catch (err) {
        add(GiftSendFailed(err.toString()));
      }
    });

    on<GiftSendSucceeded>((e, emit) async {
      // Stop spinner and close sheet (server confirmed send)
      emit(state.copyWith(isSendingGift: false, showGiftSheet: false));

      // Refresh canonical balance from wallet endpoint (do not trust sendGift payload as sole source)
      try {
        final refreshedBalance = await repo.fetchWalletBalance();
        if (refreshedBalance != null) {
          emit(state.copyWith(walletBalanceCoins: refreshedBalance));
        }
      } catch (err) {
        debugPrint('⚠️ Failed to refresh wallet after gift: $err');
        // Keep UI working with whatever we had — do not crash.
      }

      // Sender feedback toast (reuse existing path)
      add(
        _GiftArrived(
          GiftNotice(
            from: 'You',
            giftName: e.result.broadcast.giftCode,
            coins: e.result.broadcast.coinsSpent,
          ),
        ),
      );

      // Enqueue overlay for local user too
      add(GiftBroadcastReceived(e.result.broadcast));
    });

    on<GiftSendFailed>((e, emit) {
      emit(state.copyWith(isSendingGift: false, sendErrorMessage: e.message));
    });

    // === GIFTS: broadcasts drive overlay queue
    on<GiftBroadcastReceived>((e, emit) {
      final q = List<GiftBroadcast>.from(state.giftOverlayQueue)
        ..add(e.broadcast);
      emit(state.copyWith(giftOverlayQueue: q));
    });

    on<GiftOverlayDequeued>((e, emit) {
      if (state.giftOverlayQueue.isEmpty) return;
      final q = List<GiftBroadcast>.from(state.giftOverlayQueue)..removeAt(0);
      emit(state.copyWith(giftOverlayQueue: q));
    });
  }

  // Helper methods for messages
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

  String _getRemovalMessage(String reason) {
    switch (reason) {
      case 'removed_by_host':
        return 'You have been removed from the stream by the host.';
      case 'violated_guidelines':
        return 'You have been removed for violating community guidelines.';
      case 'banned':
        return 'You have been banned from this stream.';
      default:
        return 'You have been removed from the stream.';
    }
  }

  Future<void> _onStarted(
    ViewerStarted event,
    Emitter<ViewerState> emit,
  ) async {
    emit(state.copyWith(status: ViewerStatus.loading));

    final host = await repo.fetchHostInfo();

    // Prefetch wallet balance (canonical source)
    int? walletBalance;
    try {
      walletBalance = await repo.fetchWalletBalance();
    } catch (e) {
      debugPrint('⚠️ fetchWalletBalance on start failed: $e');
      walletBalance = null;
    }

    emit(
      state.copyWith(
        status: ViewerStatus.active,
        host: host,
        walletBalanceCoins: walletBalance,
        joinRequested: true,
        awaitingApproval: false,
      ),
    );

    // Cancel all existing subscriptions first
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

    // Set up all subscriptions
    _clockSub = repo.watchLiveClock().listen((d) => add(_Ticked(d)));
    _viewerSub = repo.watchViewerCount().listen(
      (c) => add(_ViewerCountUpdated(c)),
    );
    _chatSub = repo.watchChat().listen((m) => add(_ChatArrived(m)));
    _guestSub = repo.watchGuestJoins().listen((n) => add(_GuestJoined(n)));
    _giftSub = repo.watchGifts().listen((n) => add(_GiftArrived(n)));
    _pauseSub = repo.watchPause().listen((p) => add(_PauseChanged(p)));
    _endedSub = repo.watchEnded().listen((_) => add(const _LiveEnded()));
    _giftBroadcastSub?.cancel();
    _giftBroadcastSub = repo.watchGiftBroadcasts().listen(
      (b) => add(GiftBroadcastReceived(b)),
    );
    _approvalSub = repo.watchMyApproval().listen(
      (ok) => add(_MyApprovalChanged(ok)),
    );

    // ✅ CRITICAL FIX: Add the missing participant event subscriptions
    _errorSub = repo.watchErrors().listen((error) {
      if (error.isNotEmpty) {
        add(ErrorOccurred(error));
      }
    });

    _roleChangeSub = repo.watchParticipantRoleChanges().listen((role) {
      debugPrint('🎯 Role change received in bloc: $role');
      add(ParticipantRoleChanged(role));
    });

    _removalSub = repo.watchParticipantRemovals().listen((reason) {
      debugPrint('🎯 Removal received in bloc: $reason');
      add(ParticipantRemoved(reason));
    });

    // Active guest subscription
    if (repo is ViewerRepositoryImpl) {
      _activeGuestSub = (repo as ViewerRepositoryImpl)
          .watchActiveGuestUuid()
          .listen((uuid) {
            debugPrint('🎯 Active guest updated: $uuid');
            add(_ActiveGuestUpdated(uuid));
          });
    }
  }

  Future<void> _onFollowToggled(
    FollowToggled e,
    Emitter<ViewerState> emit,
  ) async {
    final newState = await repo.toggleFollow(state.host?.isFollowed ?? false);
    emit(state.copyWith(host: state.host?.copyWith(isFollowed: newState)));
  }

  Future<void> _onCommentSent(CommentSent e, Emitter<ViewerState> emit) async {
    if (e.text.trim().isEmpty) return;
    await repo.sendComment(e.text.trim());
  }

  Future<void> _onLikePressed(LikePressed e, Emitter<ViewerState> emit) async {
    final count = await repo.like();
    emit(state.copyWith(likes: count));
  }

  Future<void> _onSharePressed(
    SharePressed e,
    Emitter<ViewerState> emit,
  ) async {
    final count = await repo.share();
    emit(state.copyWith(shares: count));
  }

  Future<void> _onRequestToJoinPressed(
    RequestToJoinPressed e,
    Emitter<ViewerState> emit,
  ) async {
    try {
      await repo.requestToJoin();
      emit(state.copyWith(joinRequested: true, awaitingApproval: true));
    } catch (_) {
      // keep it enabled so user can retry
      emit(state.copyWith(joinRequested: false, awaitingApproval: false));
    }
  }

  void _autoHide(void Function() cb) {
    Future.delayed(const Duration(seconds: 4), cb);
  }

  @override
  Future<void> close() {
    _giftBroadcastSub?.cancel();
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
    repo.dispose();
    return super.close();
  }
}
