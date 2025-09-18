import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities.dart';
import '../../domain/repositories/viewer_repository.dart';

part 'viewer_event.dart';
part 'viewer_state.dart';

class ViewerBloc extends Bloc<ViewerEvent, ViewerState> {
  final ViewerRepository repo;
  StreamSubscription? _clockSub, _viewerSub, _chatSub, _guestSub, _giftSub;
  StreamSubscription? _pauseSub;
  StreamSubscription? _endedSub;
  StreamSubscription? _approvalSub;

  ViewerBloc(this.repo) : super(const ViewerState.initial()) {
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

    // Button kept for UX, but we auto-request on start too.
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
  }

  Future<void> _onStarted(
    ViewerStarted event,
    Emitter<ViewerState> emit,
  ) async {
    emit(state.copyWith(status: ViewerStatus.loading));

    final host = await repo.fetchHostInfo();
    emit(state.copyWith(status: ViewerStatus.active, host: host));

    _pauseSub?.cancel();
    _pauseSub = repo.watchPause().listen((p) => add(_PauseChanged(p)));
    _endedSub?.cancel();
    _endedSub = repo.watchEnded().listen((_) => add(const _LiveEnded()));

    _clockSub?.cancel();
    _viewerSub?.cancel();
    _chatSub?.cancel();
    _guestSub?.cancel();
    _giftSub?.cancel();
    _approvalSub?.cancel();

    _clockSub = repo.watchLiveClock().listen((d) => add(_Ticked(d)));
    _viewerSub = repo.watchViewerCount().listen(
      (c) => add(_ViewerCountUpdated(c)),
    );
    _chatSub = repo.watchChat().listen((m) => add(_ChatArrived(m)));
    _guestSub = repo.watchGuestJoins().listen((n) => add(_GuestJoined(n)));
    _giftSub = repo.watchGifts().listen((n) => add(_GiftArrived(n)));
    _approvalSub = repo.watchMyApproval().listen(
      (ok) => add(_MyApprovalChanged(ok)),
    );

    // 🚀 Auto-request join as soon as we land on the viewer screen
    try {
      await repo.requestToJoin();
      emit(state.copyWith(joinRequested: true, awaitingApproval: true));
    } catch (_) {
      // keep UI enabled; user can tap manual button
      emit(state.copyWith(joinRequested: false, awaitingApproval: false));
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
    _clockSub?.cancel();
    _viewerSub?.cancel();
    _chatSub?.cancel();
    _guestSub?.cancel();
    _giftSub?.cancel();
    _pauseSub?.cancel();
    _endedSub?.cancel();
    _approvalSub?.cancel();
    repo.dispose();
    return super.close();
  }
}
