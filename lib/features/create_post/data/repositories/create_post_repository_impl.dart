import '../../domain/entities/create_post_payload.dart';
import '../../domain/repositories/create_post_repository.dart';
import '../../../post_view/domain/entities/post.dart';
import '../../../post_view/data/models/post_dto.dart';
import '../datasources/create_post_remote_datasource.dart';

class CreatePostRepositoryImpl implements CreatePostRepository {
  final CreatePostRemoteDataSource remote;
  CreatePostRepositoryImpl(this.remote);

  @override
  Future<Post> createPost(CreatePostPayload payload) async {
    final map = await remote.createPost(payload);
    return PostDto.fromMap(map).toEntity();
  }
}
