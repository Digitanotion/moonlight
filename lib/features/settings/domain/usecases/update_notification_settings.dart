import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../repositories/account_repository.dart';
import '../entities/notification_settings.dart';

class UpdateNotificationSettings {
  final AccountRepository repository;

  UpdateNotificationSettings(this.repository);

  Future<Either<Failure, void>> call(NotificationSettings settings) async {
    return await repository.updateNotificationSettings(settings);
  }
}
