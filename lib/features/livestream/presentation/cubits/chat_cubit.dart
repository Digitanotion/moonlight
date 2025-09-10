// lib/features/livestream/presentation/cubits/chat_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/livestream/domain/entities/message.dart';
import 'package:moonlight/features/livestream/domain/repositories/livestream_repository.dart';

class ChatCubit extends Cubit<ChatState> {
  final LivestreamRepository repo;
  final String lsUuid;

  ChatCubit(this.repo, this.lsUuid) : super(const ChatState());

  Future<void> loadHistory() async {
    emit(state.copyWith(loading: true, error: null));
    final res = await repo.getMessages(lsUuid);
    res.fold(
      (f) => emit(state.copyWith(loading: false, error: f.message)),
      (list) =>
          emit(state.copyWith(loading: false, messages: list, error: null)),
    );
  }

  Future<void> send(String text) async {
    // optimistic append optional (commented); we’ll wait for server echo:
    // final optimistic = Message(
    //   uuid: 'local-${DateTime.now().microsecondsSinceEpoch}',
    //   text: text,
    //   userUuid: '', userDisplay: 'You', createdAt: DateTime.now(),
    // );
    // emit(state.copyWith(messages: [...state.messages, optimistic]));

    final res = await repo.sendMessage(lsUuid, text);
    res.fold(
      (f) {
        emit(state.copyWith(error: f.message));
      },
      (m) {
        final all = List<Message>.from(state.messages)..add(m);
        emit(state.copyWith(messages: all, error: null));
      },
    );
  }
}

class ChatState extends Equatable {
  final List<Message> messages;
  final bool loading;
  final String? error;

  const ChatState({this.messages = const [], this.loading = false, this.error});

  int get count => messages.length;

  ChatState copyWith({List<Message>? messages, bool? loading, String? error}) =>
      ChatState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        error: error,
      );

  @override
  List<Object?> get props => [messages, loading, error];
}
