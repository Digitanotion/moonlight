// lib/features/live_viewer/presentation/bloc/viewer_event.dart - ENHANCED
part of 'viewer_bloc.dart';

abstract class ViewerEvent extends Equatable {
  const ViewerEvent();
  @override
  List<Object?> get props => [];
}

// ============ EXISTING EVENTS (PRESERVED) ============
class ViewerStarted extends ViewerEvent {
  const ViewerStarted();
}

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

class RoleChangeToastDismissed extends ViewerEvent {
  const RoleChangeToastDismissed();
}

class NavigateBackRequested extends ViewerEvent {
  const NavigateBackRequested();
}

class _ActiveGuestUpdated extends ViewerEvent {
  final String? uuid;
  const _ActiveGuestUpdated(this.uuid);
  @override
  List<Object?> get props => [uuid];
}

class GiftSheetRequested extends ViewerEvent {
  const GiftSheetRequested();
}

class GiftSheetClosed extends ViewerEvent {
  const GiftSheetClosed();
}

class GiftsFetchRequested extends ViewerEvent {
  const GiftsFetchRequested();
}

class GiftSendRequested extends ViewerEvent {
  final String code;
  final int quantity;
  final String toUserUuid;
  final String livestreamId;
  const GiftSendRequested(
    this.code,
    this.quantity,
    this.toUserUuid,
    this.livestreamId,
  );
  @override
  List<Object?> get props => [code, quantity, toUserUuid, livestreamId];
}

class GiftSendSucceeded extends ViewerEvent {
  final GiftSendResult result;
  const GiftSendSucceeded(this.result);
  @override
  List<Object?> get props => [result];
}

class GiftSendFailed extends ViewerEvent {
  final String message;
  const GiftSendFailed(this.message);
  @override
  List<Object?> get props => [message];
}

class GiftBroadcastReceived extends ViewerEvent {
  final GiftBroadcast broadcast;
  const GiftBroadcastReceived(this.broadcast);
  @override
  List<Object?> get props => [broadcast];
}

class GiftOverlayDequeued extends ViewerEvent {
  const GiftOverlayDequeued();
}

// ============ NEW EVENTS FOR REQUIREMENTS ============

// Network monitoring events
class NetworkQualityUpdated extends ViewerEvent {
  final NetworkQuality selfQuality;
  final NetworkQuality hostQuality;
  final NetworkQuality? guestQuality;
  const NetworkQualityUpdated({
    required this.selfQuality,
    required this.hostQuality,
    this.guestQuality,
  });
  @override
  List<Object?> get props => [selfQuality, hostQuality, guestQuality];
}

class ConnectionStatsUpdated extends ViewerEvent {
  final ConnectionStats stats;
  const ConnectionStatsUpdated(this.stats);
  @override
  List<Object?> get props => [stats];
}

// Reconnection events
class ConnectionLost extends ViewerEvent {
  final DateTime timestamp;
  final String reason;
  const ConnectionLost({required this.timestamp, required this.reason});
  @override
  List<Object?> get props => [timestamp, reason];
}

class ReconnectionStarted extends ViewerEvent {
  const ReconnectionStarted();
}

class ReconnectionSucceeded extends ViewerEvent {
  final int attempts;
  const ReconnectionSucceeded(this.attempts);
  @override
  List<Object?> get props => [attempts];
}

class ReconnectionFailed extends ViewerEvent {
  final String error;
  final int attempts;
  const ReconnectionFailed({required this.error, required this.attempts});
  @override
  List<Object?> get props => [error, attempts];
}

class ReconnectionOverlayDismissed extends ViewerEvent {
  const ReconnectionOverlayDismissed();
}

// Guest controls events
class GuestVideoToggled extends ViewerEvent {
  final bool enabled;
  const GuestVideoToggled(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class GuestAudioToggled extends ViewerEvent {
  final bool enabled;
  const GuestAudioToggled(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class GuestControlsUpdated extends ViewerEvent {
  final GuestControlsState controls;
  const GuestControlsUpdated(this.controls);
  @override
  List<Object?> get props => [controls];
}

// Mode switching events
class ModeSwitched extends ViewerEvent {
  final ViewMode mode;
  const ModeSwitched(this.mode);
  @override
  List<Object?> get props => [mode];
}

class NetworkStatusVisibilityToggled extends ViewerEvent {
  final bool visible;
  const NetworkStatusVisibilityToggled(this.visible);
  @override
  List<Object?> get props => [visible];
}
