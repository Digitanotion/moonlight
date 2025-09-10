import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/livestream.dart';
import '../../domain/usecases/create_livestream.dart';

part 'go_live_state.dart';

class GoLiveCubit extends Cubit<GoLiveState> {
  GoLiveCubit(this._createLivestream) : super(const GoLiveState());

  final CreateLivestream _createLivestream;

  void titleChanged(String v) => emit(state.copyWith(title: v));
  void categoryChanged(String? v) => emit(state.copyWith(category: v));
  void recordToggled(bool v) => emit(state.copyWith(record: v));
  void allowGuestBoxToggled(bool v) => emit(state.copyWith(allowGuests: v));
  void enableCommentsToggled(bool v) => emit(state.copyWith(enableComments: v));
  void showViewerCountToggled(bool v) =>
      emit(state.copyWith(showViewerCount: v));

  Future<void> submit() async {
    if (state.title.trim().isEmpty) {
      emit(
        state.copyWith(
          status: GoLiveStatus.error,
          message: 'Give your stream a title',
        ),
      );
      return;
    }
    emit(state.copyWith(status: GoLiveStatus.submitting, message: null));

    final res = await _createLivestream(
      CreateLivestreamParams(
        title: state.title.trim(),
        record: state.record,
        visibility: state.visibility, // 'public' by default
        clubUuid: state.clubUuid,
        invitees: const [], // extend later if UI adds chips
      ),
    );

    res.fold(
      (failure) => emit(
        state.copyWith(status: GoLiveStatus.error, message: failure.message),
      ),
      (live) =>
          emit(state.copyWith(status: GoLiveStatus.success, created: live)),
    );
  }
}
