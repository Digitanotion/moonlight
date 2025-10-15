import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/core/network/error_parser.dart';
import '../../domain/entities/create_post_payload.dart';
import '../../domain/repositories/create_post_repository.dart';
import '../../../post_view/domain/entities/post.dart';

class CreatePostState extends Equatable {
  final bool submitting;
  final String? error;
  final Post? created;

  const CreatePostState({this.submitting = false, this.error, this.created});

  CreatePostState copyWith({bool? submitting, String? error, Post? created}) {
    return CreatePostState(
      submitting: submitting ?? this.submitting,
      error: error,
      created: created,
    );
  }

  @override
  List<Object?> get props => [submitting, error, created];
}

class CreatePostCubit extends Cubit<CreatePostState> {
  final CreatePostRepository repo;
  CreatePostCubit(this.repo) : super(const CreatePostState());

  Future<void> submit(CreatePostPayload payload) async {
    emit(state.copyWith(submitting: true, error: null));
    try {
      final post = await repo.createPost(payload);
      emit(CreatePostState(submitting: false, created: post));
    } catch (e) {
      emit(state.copyWith(submitting: false, error: apiErrorMessage(e)));
    }
  }
}
