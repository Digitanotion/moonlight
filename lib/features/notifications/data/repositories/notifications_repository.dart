import '../datasources/notifications_remote_data_source.dart';
import '../models/notification_model.dart';

class NotificationPage {
  final List<NotificationModel> items;
  final int total;

  NotificationPage({required this.items, required this.total});
}

abstract class NotificationsRepository {
  Future<NotificationPage> fetch({required int page, required int perPage});

  Future<void> markRead(String id);
  Future<void> markAllRead();
}

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource remote;

  NotificationsRepositoryImpl(this.remote);

  @override
  Future<NotificationPage> fetch({
    required int page,
    required int perPage,
  }) async {
    final map = await remote.fetch(page: page, perPage: perPage);

    final raw = (map['data'] as List?) ?? const [];
    final items = raw.map((e) => NotificationModel.fromMap(e)).toList();

    return NotificationPage(
      items: items,
      total: (map['meta']?['total'] as num?)?.toInt() ?? items.length,
    );
  }

  @override
  Future<void> markRead(String id) => remote.markRead(id);

  @override
  Future<void> markAllRead() => remote.markAllRead();
}
