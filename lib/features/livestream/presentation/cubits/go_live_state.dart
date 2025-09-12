import 'package:moonlight/features/livestream/domain/entities/live_category.dart';

class GoLiveState {
  // Media
  final String? coverPath;
  final String title;
  final LiveCategory? category;

  // Toggles
  final bool premium;
  final bool allowGuestBox;
  final bool comments;
  final bool showCount;

  // Devices (desired state the user selected)
  final bool micOn;
  final bool camOn;

  // Device readiness/results
  final bool camReady;
  final bool micReady;
  final double micLevel; // 0..1

  // Loading / actions
  final bool loading;
  final bool starting;
  final bool eligibleBonus;

  // Preview
  final bool previewReady;
  final int estLow;
  final int estHigh;
  final String bestTime;

  // Data + error
  final List<LiveCategory> categories;
  final String? error;

  const GoLiveState({
    this.coverPath,
    this.title = '',
    this.category,
    this.premium = false,
    this.allowGuestBox = false,
    this.comments = true,
    this.showCount = true,
    this.micOn = true,
    this.camOn = false,
    this.camReady = false,
    this.micReady = false,
    this.micLevel = 0.0,
    this.loading = false,
    this.starting = false,
    this.eligibleBonus = false,
    this.previewReady = false,
    this.estLow = 0,
    this.estHigh = 0,
    this.bestTime = 'Now',
    this.categories = const [],
    this.error,
  });

  bool get canStart => title.trim().isNotEmpty && category != null && !starting;
  bool get devicesOk => (!camOn || camReady) && (!micOn || micReady);

  GoLiveState copyWith({
    String? coverPath,
    String? title,
    LiveCategory? category,
    bool? premium,
    bool? allowGuestBox,
    bool? comments,
    bool? showCount,
    bool? micOn,
    bool? camOn,
    bool? camReady,
    bool? micReady,
    double? micLevel,
    bool? loading,
    bool? starting,
    bool? eligibleBonus,
    bool? previewReady,
    int? estLow,
    int? estHigh,
    String? bestTime,
    List<LiveCategory>? categories,
    String? error,
    bool clearError = false,
  }) {
    return GoLiveState(
      coverPath: coverPath ?? this.coverPath,
      title: title ?? this.title,
      category: category ?? this.category,
      premium: premium ?? this.premium,
      allowGuestBox: allowGuestBox ?? this.allowGuestBox,
      comments: comments ?? this.comments,
      showCount: showCount ?? this.showCount,
      micOn: micOn ?? this.micOn,
      camOn: camOn ?? this.camOn,
      camReady: camReady ?? this.camReady,
      micReady: micReady ?? this.micReady,
      micLevel: micLevel ?? this.micLevel,
      loading: loading ?? this.loading,
      starting: starting ?? this.starting,
      eligibleBonus: eligibleBonus ?? this.eligibleBonus,
      previewReady: previewReady ?? this.previewReady,
      estLow: estLow ?? this.estLow,
      estHigh: estHigh ?? this.estHigh,
      bestTime: bestTime ?? this.bestTime,
      categories: categories ?? this.categories,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  String toString() =>
      'GoLiveState(title:$title, cat:${category?.name}, micOn:$micOn, micReady:$micReady, '
      'camOn:$camOn, camReady:$camReady, micLevel:$micLevel, starting:$starting)';
}
