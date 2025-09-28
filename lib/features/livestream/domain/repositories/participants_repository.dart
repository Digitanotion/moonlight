import '../entities/participant.dart';
import '../entities/paginated.dart';

abstract class ParticipantsRepository {
  /// Numeric livestream id for sockets; string param (id or uuid) for REST paths
  int get livestreamIdNumeric;
  String get livestreamParam;

  /// Page starts at 1; optional role filter ("guest","audience","publisher")
  Future<Paginated<Participant>> list({int page = 1, String? role});

  /// Promote/demote role. Backend expects {"role":"guest"} etc.
  Future<Participant> changeRole(String userUuid, String role);

  /// Remove participant from stream
  Future<void> remove(String userUuid);

  /// Realtime streams (Pusher)
  Stream<Participant> participantAddedStream();
  Stream<String> participantRemovedStream(); // emits userUuid
  Stream<MapEntry<String, String>> roleChangedStream(); // userUuid -> role

  /// Call before leaving page
  Future<void> dispose();
}
