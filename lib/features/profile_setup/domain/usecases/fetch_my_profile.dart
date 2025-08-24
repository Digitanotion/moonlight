import '../repositories/profile_repository.dart';
import 'package:moonlight/features/auth/data/models/user_model.dart';

class FetchMyProfile {
  final ProfileRepository repo;
  FetchMyProfile(this.repo);

  Future<UserModel> call() => repo.fetchMyProfile();
}
