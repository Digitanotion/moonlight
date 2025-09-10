// lib/features/livestream/presentation/cubits/gifts_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/livestream/domain/repositories/livestream_repository.dart';

// part 'gifts_state.dart';

class GiftsCubit extends Cubit<GiftsState> {
  final LivestreamRepository repo;
  final String lsUuid;
  GiftsCubit(this.repo, this.lsUuid) : super(const GiftsState(balance: 0));

  Future<void> sendGift(String type, int coins) async {
    emit(state.copyWith(sending: true));
    final res = await repo.sendGift(lsUuid, type, coins);
    res.fold(
      (f) => emit(state.copyWith(sending: false, error: f.message)),
      (balance) => emit(
        state.copyWith(
          sending: false,
          balance: balance,
          lastNotice: 'Sent $type ($coins)',
        ),
      ),
    );
  }
}

class GiftsState extends Equatable {
  final int balance;
  final bool sending;
  final String? lastNotice;
  final String? error;
  const GiftsState({
    required this.balance,
    this.sending = false,
    this.lastNotice,
    this.error,
  });
  GiftsState copyWith({
    int? balance,
    bool? sending,
    String? lastNotice,
    String? error,
  }) => GiftsState(
    balance: balance ?? this.balance,
    sending: sending ?? this.sending,
    lastNotice: lastNotice,
    error: error,
  );
  @override
  List<Object?> get props => [balance, sending, lastNotice, error];
}
