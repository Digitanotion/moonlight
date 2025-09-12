// =============================================
// LAYER: APPLICATION (BLoC/Cubit)
// =============================================

// -----------------------------
// FILE: lib/features/live/application/live_cubits.dart
// -----------------------------
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/livestream/domain/entities/live_entities.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_repository.dart';

class LiveMetaState extends Equatable {
  final LiveMeta meta;
  final LiveHost host;
  const LiveMetaState({required this.meta, required this.host});
  @override
  List<Object?> get props => [meta, host];
}

class LiveMetaCubit extends Cubit<LiveMetaState> {
  final LiveRepository repo;
  late final StreamSubscription _sub;
  LiveMetaCubit({required this.repo, required LiveHost host})
    : super(
        LiveMetaState(
          meta: const LiveMeta(
            topic: '',
            elapsed: Duration.zero,
            viewers: 0,
            isPaused: false,
          ),
          host: host,
        ),
      ) {
    _sub = repo.meta$().listen((m) => emit(LiveMetaState(meta: m, host: host)));
  }
  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}

class ChatState extends Equatable {
  final List<ChatMessage> messages;
  const ChatState(this.messages);
  @override
  List<Object?> get props => [messages];
}

class ChatCubit extends Cubit<ChatState> {
  final LiveRepository repo;
  late final StreamSubscription _sub;
  ChatCubit(this.repo) : super(const ChatState(const [])) {
    _sub = repo.chat$().listen((msgs) => emit(ChatState(msgs)));
  }
  Future<void> send(String text) => repo.sendComment(text);
  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}

class BannerState extends Equatable {
  final GiftEvent? gift;
  final GuestJoinEvent? guest;
  const BannerState({this.gift, this.guest});
  @override
  List<Object?> get props => [gift, guest];
}

class BannerCubit extends Cubit<BannerState> {
  final LiveRepository repo;
  late final StreamSubscription _gSub;
  late final StreamSubscription _jSub;
  BannerCubit(this.repo) : super(const BannerState()) {
    _gSub = repo.giftBanner$().listen(
      (g) => emit(BannerState(gift: g, guest: state.guest)),
    );
    _jSub = repo.guestBanner$().listen(
      (j) => emit(BannerState(gift: state.gift, guest: j)),
    );
  }
  Future<void> requestToJoin() => repo.requestToJoin();
  @override
  Future<void> close() {
    _gSub.cancel();
    _jSub.cancel();
    return super.close();
  }
}
