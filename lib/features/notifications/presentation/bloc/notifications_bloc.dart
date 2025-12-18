import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/notifications/data/models/notification_model.dart';
import 'package:moonlight/features/notifications/data/repositories/notifications_repository.dart';

abstract class NotificationsEvent {}

class FetchNotifications extends NotificationsEvent {
  final bool refresh;
  FetchNotifications({this.refresh = false});
}

class LoadMoreNotifications extends NotificationsEvent {}

class MarkNotificationRead extends NotificationsEvent {
  final String id;
  MarkNotificationRead(this.id);
}

class MarkAllNotificationsRead extends NotificationsEvent {}

abstract class NotificationsState {}

class NotificationsLoading extends NotificationsState {}

class NotificationsLoaded extends NotificationsState {
  final List<NotificationModel> items;
  final bool hasMore;
  final bool isPaginating;

  NotificationsLoaded({
    required this.items,
    required this.hasMore,
    this.isPaginating = false,
  });
}

class NotificationsEmpty extends NotificationsState {}

class NotificationsError extends NotificationsState {}

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final NotificationsRepository repo;

  int _page = 1;
  final int _perPage = 25;
  bool _hasMore = true;
  List<NotificationModel> _items = [];

  NotificationsBloc(this.repo) : super(NotificationsLoading()) {
    on<FetchNotifications>(_fetch);
    on<LoadMoreNotifications>(_loadMore);
    on<MarkNotificationRead>(_markRead);
    on<MarkAllNotificationsRead>(_markAllRead);
  }

  Future<void> _fetch(
    FetchNotifications event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      if (!event.refresh) emit(NotificationsLoading());

      _page = 1;
      final res = await repo.fetch(page: _page, perPage: _perPage);
      _items = res.items;
      _hasMore = _items.length < res.total;

      if (_items.isEmpty) {
        emit(NotificationsEmpty());
      } else {
        emit(NotificationsLoaded(items: _items, hasMore: _hasMore));
      }
    } catch (_) {
      emit(NotificationsError());
    }
  }

  Future<void> _loadMore(
    LoadMoreNotifications event,
    Emitter<NotificationsState> emit,
  ) async {
    if (!_hasMore || state is! NotificationsLoaded) return;

    emit(
      NotificationsLoaded(items: _items, hasMore: _hasMore, isPaginating: true),
    );

    _page++;
    final res = await repo.fetch(page: _page, perPage: _perPage);
    _items.addAll(res.items);
    _hasMore = _items.length < res.total;

    emit(NotificationsLoaded(items: _items, hasMore: _hasMore));
  }

  Future<void> _markRead(
    MarkNotificationRead event,
    Emitter<NotificationsState> emit,
  ) async {
    _items = _items
        .map((n) => n.id == event.id ? n.copyWith(isRead: true) : n)
        .toList();

    emit(NotificationsLoaded(items: _items, hasMore: _hasMore));
    repo.markRead(event.id);
  }

  Future<void> _markAllRead(
    MarkAllNotificationsRead event,
    Emitter<NotificationsState> emit,
  ) async {
    _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    emit(NotificationsLoaded(items: _items, hasMore: _hasMore));
    repo.markAllRead();
  }
}
