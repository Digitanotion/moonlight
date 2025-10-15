import '../entities/create_post_payload.dart';
import '../../../post_view/domain/entities/post.dart';

abstract class CreatePostRepository {
  Future<Post> createPost(CreatePostPayload payload);
}
