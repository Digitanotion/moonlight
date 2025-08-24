import '../repositories/profile_repository.dart';

class UpdateInterests {
  final ProfileRepository repo;
  UpdateInterests(this.repo);
  Future<void> call(List<String> interests) => repo.updateInterests(interests);
}
