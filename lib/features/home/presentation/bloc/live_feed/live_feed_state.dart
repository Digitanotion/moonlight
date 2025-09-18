import 'package:equatable/equatable.dart';
import '../../../domain/entities/live_item.dart';

enum LiveFeedStatus { initial, loading, success, empty, failure }

class LiveFeedState extends Equatable {
  final LiveFeedStatus status;
  final List<LiveItem> items;
  final int page;
  final int perPage;
  final int total;
  final bool hasMore;
  final String? error;
  final String? selectedCountryIso; // <— for header

  const LiveFeedState({
    this.status = LiveFeedStatus.initial,
    this.items = const [],
    this.page = 0,
    this.perPage = 20,
    this.total = 0,
    this.hasMore = true,
    this.error,
    this.selectedCountryIso,
  });

  LiveFeedState copyWith({
    LiveFeedStatus? status,
    List<LiveItem>? items,
    int? page,
    int? perPage,
    int? total,
    bool? hasMore,
    String? error,

    // IMPORTANT: use the flag to explicitly set null
    String? selectedCountryIso,
    bool setSelectedCountryIso = false,
  }) {
    return LiveFeedState(
      status: status ?? this.status,
      items: items ?? this.items,
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      selectedCountryIso: setSelectedCountryIso
          ? selectedCountryIso
          : this.selectedCountryIso,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    page,
    perPage,
    total,
    hasMore,
    error,
    selectedCountryIso,
  ];
}
