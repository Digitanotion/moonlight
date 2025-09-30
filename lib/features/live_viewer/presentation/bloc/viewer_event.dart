part of 'viewer_bloc.dart';

abstract class ViewerEvent extends Equatable {
  const ViewerEvent();
  @override
  List<Object?> get props => [];
}

class ViewerStarted extends ViewerEvent {
  const ViewerStarted();
}

// internal stream events
class _Ticked extends ViewerEvent {
  final Duration elapsed;
  const _Ticked(this.elapsed);
  @override
  List<Object?> get props => [elapsed];
}

class _ViewerCountUpdated extends ViewerEvent {
  final int count;
  const _ViewerCountUpdated(this.count);
  @override
  List<Object?> get props => [count];
}

class _ChatArrived extends ViewerEvent {
  final ChatMessage message;
  const _ChatArrived(this.message);
  @override
  List<Object?> get props => [message];
}

class _GuestJoined extends ViewerEvent {
  final GuestJoinNotice notice;
  const _GuestJoined(this.notice);
  @override
  List<Object?> get props => [notice];
}

class _GiftArrived extends ViewerEvent {
  final GiftNotice notice;
  const _GiftArrived(this.notice);
  @override
  List<Object?> get props => [notice];
}

class GuestBannerDismissed extends ViewerEvent {
  const GuestBannerDismissed();
}

class GiftToastDismissed extends ViewerEvent {
  const GiftToastDismissed();
}

// user actions
class FollowToggled extends ViewerEvent {
  const FollowToggled();
}

class CommentSent extends ViewerEvent {
  final String text;
  const CommentSent(this.text);
  @override
  List<Object?> get props => [text];
}

class LikePressed extends ViewerEvent {
  const LikePressed();
}

class SharePressed extends ViewerEvent {
  const SharePressed();
}

class RequestToJoinPressed extends ViewerEvent {
  const RequestToJoinPressed();
}

class ChatVisibilityToggled extends ViewerEvent {
  const ChatVisibilityToggled();
}

class ChatShowRequested extends ViewerEvent {
  const ChatShowRequested();
}

class ChatHideRequested extends ViewerEvent {
  const ChatHideRequested();
}

class _PauseChanged extends ViewerEvent {
  final bool paused;
  const _PauseChanged(this.paused);
  @override
  List<Object?> get props => [paused];
}

class _LiveEnded extends ViewerEvent {
  const _LiveEnded();
}

/// 👇 NEW: repo reported my request was accepted/declined
class _MyApprovalChanged extends ViewerEvent {
  final bool accepted;
  const _MyApprovalChanged(this.accepted);
  @override
  List<Object?> get props => [accepted];
}

class ErrorOccurred extends ViewerEvent {
  final String message;
  const ErrorOccurred(this.message);
  @override
  List<Object?> get props => [message];
}

class ParticipantRoleChanged extends ViewerEvent {
  final String role;
  const ParticipantRoleChanged(this.role);
  @override
  List<Object?> get props => [role];
}

class ParticipantRemoved extends ViewerEvent {
  final String reason;
  const ParticipantRemoved(this.reason);
  @override
  List<Object?> get props => [reason];
}

// ✅ ADD THESE MISSING EVENT CLASSES
class RoleChangeToastDismissed extends ViewerEvent {
  const RoleChangeToastDismissed();
}

class NavigateBackRequested extends ViewerEvent {
  const NavigateBackRequested();
}
