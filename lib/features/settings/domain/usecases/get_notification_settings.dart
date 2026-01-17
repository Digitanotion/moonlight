import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../repositories/account_repository.dart';
import '../entities/notification_settings.dart';

class GetNotificationSettings {
  final AccountRepository repository;

  GetNotificationSettings(this.repository);

  Future<Either<Failure, NotificationSettings>> call() async {
    return await repository.getNotificationSettings();
  }
}
