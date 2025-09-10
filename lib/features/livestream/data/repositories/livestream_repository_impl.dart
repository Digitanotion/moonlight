// lib/features/livestream/data/repositories/livestream_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/livestream/domain/entities/message.dart';

import '../../domain/entities/livestream.dart';
import '../../domain/repositories/livestream_repository.dart';
import '../datasources/livestream_remote_ds.dart';

class LivestreamRepositoryImpl implements LivestreamRepository {
  final LivestreamRemoteDataSource remote;
  LivestreamRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, List<Livestream>>> getActive() async {
    try {
      final list = await remote.getActive();
      return Right(list.map((e) => e.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, Livestream>> createLivestream({
    required String title,
    required bool record,
    required String visibility,
    String? clubUuid,
    required List<String> invitees,
  }) async {
    try {
      final t = await remote.start(
        title: title,
        visibility: visibility,
        record: record,
        clubUuid: clubUuid,
        invitees: invitees,
      );
      // Build a Livestream domain entity from the start response.
      // Adjust field names to your actual Livestream constructor.
      final entity = Livestream(
        uuid: t.uuid,
        title: title,
        channelName: t.channelName,
        visibility: visibility,
        status: 'live', // or t.status if provided by API
        startTime: DateTime.now(), // or parse from response if present
        // replayUrl: null,
        host: null, // fill if you have the data in `t`
      );
      return Right(entity);
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, Map<String, String>>> start(
    Map<String, dynamic> body,
  ) async {
    try {
      final t = await remote.start(
        title: body['title'],
        visibility: body['visibility'] ?? 'public',
        record: body['record'],
        clubUuid: body['club_uuid'],
        invitees: (body['invitees'] as List?)?.cast<String>(),
      );
      return Right({
        'uuid': t.uuid,
        'channel': t.channelName,
        'token': t.rtcToken,
        'appId': t.agoraAppId,
      });
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, Map<String, String>>> token(
    String lsUuid, {
    String role = 'audience',
  }) async {
    try {
      final t = await remote.requestToken(lsUuid, role: role);
      return Right({
        'uuid': t.uuid,
        'channel': t.channelName,
        'token': t.rtcToken,
        'appId': t.agoraAppId,
      });
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, void>> stop(String lsUuid) async {
    try {
      await remote.stop(lsUuid);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, void>> pause(String lsUuid) async {
    try {
      await remote.pause(lsUuid);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, void>> resume(String lsUuid) async {
    try {
      await remote.resume(lsUuid);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, List<Message>>> getMessages(String lsUuid) async {
    try {
      final list = await remote.getMessages(lsUuid);
      return Right(list.map((e) => e.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, Message>> sendMessage(
    String lsUuid,
    String text,
  ) async {
    try {
      final m = await remote.sendMessage(lsUuid, text);
      return Right(m.toEntity());
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, int>> sendGift(
    String lsUuid,
    String type,
    int coins,
  ) async {
    try {
      final g = await remote.sendGift(lsUuid, type, coins);
      return Right(g.balance);
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getViewers(
    String lsUuid,
  ) async {
    try {
      final v = await remote.getViewers(lsUuid);
      return Right(v);
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, void>> requestCohost(
    String lsUuid, {
    String? note,
  }) async {
    try {
      await remote.requestCohost(lsUuid, note: note);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getRequests(
    String lsUuid,
  ) async {
    try {
      final list = await remote.getRequests(lsUuid);
      return Right(list);
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, void>> acceptRequest(
    String lsUuid,
    String userUuid,
  ) async {
    try {
      await remote.acceptRequest(lsUuid, userUuid);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, void>> declineRequest(
    String lsUuid,
    String userUuid,
  ) async {
    try {
      await remote.declineRequest(lsUuid, userUuid);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  @override
  Future<Either<Failure, void>> removeCohost(
    String lsUuid,
    String userUuid,
  ) async {
    try {
      await remote.removeCohost(lsUuid, userUuid);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(_msg(e)));
    }
  }

  String _msg(Object e) =>
      (e is DioException &&
          e.response?.data is Map &&
          (e.response!.data['message'] != null))
      ? e.response!.data['message']
      : 'Something went wrong';
}
