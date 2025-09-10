// lib/features/livestream/presentation/cubits/live_player_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/livestream/domain/repositories/livestream_repository.dart';

// part 'live_player_state.dart';

class LivePlayerCubit extends Cubit<LivePlayerState> {
  final LivestreamRepository repo;
  LivePlayerCubit(this.repo) : super(const LivePlayerState());

  Future<void> loadToken(String lsUuid, {String role = 'audience'}) async {
    emit(state.copyWith(status: LiveStatus.loading));
    final res = await repo.token(lsUuid, role: role);
    res.fold(
      (f) => emit(state.copyWith(status: LiveStatus.failure, error: f.message)),
      (m) => emit(
        state.copyWith(
          status: LiveStatus.ready,
          livestreamUuid: m['uuid'],
          channelName: m['channel'],
          rtcToken: m['token'],
          appId: m['appId'],
          role: role,
        ),
      ),
    );
  }

  void setPaused(bool v) {
    emit(state.copyWith(paused: v));
  }

  void setGuestJoined(bool v) {
    emit(state.copyWith(guestJoined: v));
  }
}

class LivePlayerState extends Equatable {
  final LiveStatus status;
  final String? livestreamUuid;
  final String? channelName;
  final String? rtcToken;
  final String? appId;
  final String role; // audience|publisher
  final bool paused;
  final bool guestJoined;
  final String? error;

  const LivePlayerState({
    this.status = LiveStatus.idle,
    this.livestreamUuid,
    this.channelName,
    this.rtcToken,
    this.appId,
    this.role = 'audience',
    this.paused = false,
    this.guestJoined = false,
    this.error,
  });

  LivePlayerState copyWith({
    LiveStatus? status,
    String? livestreamUuid,
    String? channelName,
    String? rtcToken,
    String? appId,
    String? role,
    bool? paused,
    bool? guestJoined,
    String? error,
  }) => LivePlayerState(
    status: status ?? this.status,
    livestreamUuid: livestreamUuid ?? this.livestreamUuid,
    channelName: channelName ?? this.channelName,
    rtcToken: rtcToken ?? this.rtcToken,
    appId: appId ?? this.appId,
    role: role ?? this.role,
    paused: paused ?? this.paused,
    guestJoined: guestJoined ?? this.guestJoined,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    livestreamUuid,
    channelName,
    rtcToken,
    appId,
    role,
    paused,
    guestJoined,
    error,
  ];
}

enum LiveStatus { idle, loading, ready, failure }
