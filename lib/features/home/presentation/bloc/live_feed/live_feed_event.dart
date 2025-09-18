import 'package:equatable/equatable.dart';

abstract class LiveFeedEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LiveFeedStarted extends LiveFeedEvent {
  final String? countryIso; // null => no filter
  final String order;
  LiveFeedStarted({this.countryIso, this.order = 'trending'});
}

class LiveFeedLoadMore extends LiveFeedEvent {}

class LiveFeedRefresh extends LiveFeedEvent {}

class LiveFeedCountryChanged extends LiveFeedEvent {
  final String? countryIso; // null => All Countries
  LiveFeedCountryChanged(this.countryIso);
}
