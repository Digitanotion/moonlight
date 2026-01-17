import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:uuid/uuid.dart';

part 'donate_club_state.dart';

class DonateClubCubit extends Cubit<DonateClubState> {
  final ClubsRepository repository;
  final String club;

  DonateClubCubit({required this.repository, required this.club})
    : super(const DonateClubState.initial()) {
    loadBalance();
  }

  Future<void> loadBalance() async {
    try {
      final balance = await repository.getMyBalance();
      emit(state.copyWith(balance: balance));
    } catch (_) {
      // optional: handle silently or emit error
    }
  }

  Future<void> donate({required int coins, String? message}) async {
    if (state.loading) return;

    emit(state.copyWith(loading: true, error: null));

    try {
      await repository.donateToClub(
        club: club,
        coins: coins,
        reason: message,
        idempotencyKey: const Uuid().v4(),
      );

      // refresh balance after success
      final updatedBalance = await repository.getMyBalance();

      emit(
        state.copyWith(loading: false, success: true, balance: updatedBalance),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Donation failed. Please try again.',
        ),
      );
    }
  }

  void reset() => emit(const DonateClubState.initial());
}
