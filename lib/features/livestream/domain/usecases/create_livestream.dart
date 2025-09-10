import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/livestream.dart';
import '../repositories/livestream_repository.dart';

class CreateLivestreamParams {
  final String title;
  final bool record;
  final String visibility;
  final String? clubUuid;
  final List<String> invitees;

  CreateLivestreamParams({
    required this.title,
    required this.record,
    required this.visibility,
    this.clubUuid,
    required this.invitees,
  });
}

class CreateLivestream {
  final LivestreamRepository repo;
  CreateLivestream(this.repo);

  Future<Either<Failure, Livestream>> call(CreateLivestreamParams p) {
    return repo.createLivestream(
      title: p.title,
      record: p.record,
      visibility: p.visibility,
      clubUuid: p.clubUuid,
      invitees: p.invitees,
    );
  }
}
