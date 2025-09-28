part of 'participants_bloc.dart';

abstract class ParticipantsEvent extends Equatable {
  const ParticipantsEvent();
  @override
  List<Object?> get props => [];
}

class ParticipantsStarted extends ParticipantsEvent {
  final String? role; // optional filter
  const ParticipantsStarted({this.role});
}

class ParticipantsRefreshed extends ParticipantsEvent {
  const ParticipantsRefreshed();
}

class ParticipantsNextPageRequested extends ParticipantsEvent {
  const ParticipantsNextPageRequested();
}

class ParticipantActionRemove extends ParticipantsEvent {
  final String userUuid;
  const ParticipantActionRemove(this.userUuid);
  @override
  List<Object?> get props => [userUuid];
}

class ParticipantActionRole extends ParticipantsEvent {
  final String userUuid;
  final String role; // "guest"|"audience"|...
  const ParticipantActionRole(this.userUuid, this.role);
  @override
  List<Object?> get props => [userUuid, role];
}

// internal socket events
class _SockAdded extends ParticipantsEvent {
  final Participant p;
  const _SockAdded(this.p);
  @override
  List<Object?> get props => [p.userUuid];
}

class _SockRemoved extends ParticipantsEvent {
  final String userUuid;
  const _SockRemoved(this.userUuid);
  @override
  List<Object?> get props => [userUuid];
}

class _SockRoleChanged extends ParticipantsEvent {
  final String userUuid;
  final String role;
  const _SockRoleChanged(this.userUuid, this.role);
  @override
  List<Object?> get props => [userUuid, role];
}
