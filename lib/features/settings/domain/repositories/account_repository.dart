import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/settings/domain/entities/notification_settings.dart';

abstract class AccountRepository {
  Future<Either<Failure, void>> deactivate({
    required String confirm, // must be "DEACTIVATE"
    String? password,
    String? reason,
  });

  Future<Either<Failure, void>> reactivate();

  Future<Either<Failure, void>> deleteAccount({
    required String confirm, // must be "DELETE"
    String? password,
  });

  Future<Either<Failure, NotificationSettings>> getNotificationSettings();

  Future<Either<Failure, void>> updateNotificationSettings(
    NotificationSettings settings,
  );

  Future<Either<Failure, Map<String, dynamic>>> getDeletionStatus();
  Future<Either<Failure, void>> requestDeletion({
    required String confirm,
    String? password,
    required String reason,
    String? feedback,
  });
  Future<Either<Failure, void>> cancelDeletion({required String confirm});
}
