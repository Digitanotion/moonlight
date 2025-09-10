// lib/features/livestream/domain/repositories/livestream_repository.dart
import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import '../entities/livestream.dart';
import '../entities/message.dart';

abstract class LivestreamRepository {
  Future<Either<Failure, List<Livestream>>> getActive();
  Future<Either<Failure, Map<String, String>>> start(Map<String, dynamic> body);
  Future<Either<Failure, Map<String, String>>> token(
    String lsUuid, {
    String role = 'audience',
  });
  Future<Either<Failure, Livestream>> createLivestream({
    required String title,
    required bool record,
    required String visibility,
    String? clubUuid,
    required List<String> invitees,
  });
  Future<Either<Failure, void>> stop(String lsUuid);
  Future<Either<Failure, void>> pause(String lsUuid);
  Future<Either<Failure, void>> resume(String lsUuid);
  Future<Either<Failure, List<Message>>> getMessages(String lsUuid);
  Future<Either<Failure, Message>> sendMessage(String lsUuid, String text);
  Future<Either<Failure, int>> sendGift(String lsUuid, String type, int coins);
  Future<Either<Failure, Map<String, dynamic>>> getViewers(String lsUuid);
  Future<Either<Failure, void>> requestCohost(String lsUuid, {String? note});
  Future<Either<Failure, List<Map<String, dynamic>>>> getRequests(
    String lsUuid,
  );
  Future<Either<Failure, void>> acceptRequest(String lsUuid, String userUuid);
  Future<Either<Failure, void>> declineRequest(String lsUuid, String userUuid);
  Future<Either<Failure, void>> removeCohost(String lsUuid, String userUuid);
}
