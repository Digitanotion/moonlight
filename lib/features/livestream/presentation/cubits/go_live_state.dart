part of 'go_live_cubit.dart';

enum GoLiveStatus { idle, submitting, success, error }

class GoLiveState extends Equatable {
  const GoLiveState({
    this.title = '',
    this.category,
    this.record = false,
    this.allowGuests = false,
    this.enableComments = true,
    this.showViewerCount = true,
    this.visibility = 'public',
    this.clubUuid,
    this.status = GoLiveStatus.idle,
    this.message,
    this.created,
  });

  final String title;
  final String? category;
  final bool record;
  final bool allowGuests;
  final bool enableComments;
  final bool showViewerCount;
  final String visibility; // public|followers|private|club
  final String? clubUuid;
  final GoLiveStatus status;
  final String? message;
  final Livestream? created;

  GoLiveState copyWith({
    String? title,
    String? category,
    bool? record,
    bool? allowGuests,
    bool? enableComments,
    bool? showViewerCount,
    String? visibility,
    String? clubUuid,
    GoLiveStatus? status,
    String? message,
    Livestream? created,
  }) {
    return GoLiveState(
      title: title ?? this.title,
      category: category ?? this.category,
      record: record ?? this.record,
      allowGuests: allowGuests ?? this.allowGuests,
      enableComments: enableComments ?? this.enableComments,
      showViewerCount: showViewerCount ?? this.showViewerCount,
      visibility: visibility ?? this.visibility,
      clubUuid: clubUuid ?? this.clubUuid,
      status: status ?? this.status,
      message: message,
      created: created ?? this.created,
    );
  }

  @override
  List<Object?> get props => [
    title,
    category,
    record,
    allowGuests,
    enableComments,
    showViewerCount,
    visibility,
    clubUuid,
    status,
    message,
    created,
  ];
}
