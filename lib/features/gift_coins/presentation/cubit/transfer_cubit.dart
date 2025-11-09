// lib/features/gift_coins/presentation/cubit/transfer_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/gift_user.dart';
import '../../domain/repositories/gift_repository.dart';
import 'package:uuid/uuid.dart';

part 'transfer_state.dart';

class TransferCubit extends Cubit<TransferState> {
  final GiftRepository repository;
  String? _lastRecipientUuid;
  int? _lastAmount;
  String? _lastMessage;
  String? _lastPin;

  TransferCubit({required this.repository}) : super(TransferState.initial());

  /// Load user's current wallet balance
  Future<void> loadBalance() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final balance = await repository.getBalance();
      emit(state.copyWith(loading: false, balance: balance));
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Unable to load balance: ${_short(e.toString())}',
        ),
      );
    }
  }

  /// Search for users
  Future<void> searchUsers(String query) async {
    emit(
      state.copyWith(
        searchLoading: true,
        searchQuery: query,
        searchError: null,
      ),
    );
    try {
      final results = await repository.searchUsers(query);
      emit(state.copyWith(searchLoading: false, searchResults: results));
    } catch (e) {
      emit(
        state.copyWith(searchLoading: false, searchError: _short(e.toString())),
      );
    }
  }

  /// Update selected user from search results
  void selectUser(GiftUser user) {
    final newCanSend = (state.amount != null && state.amount! > 0);
    emit(state.copyWith(selectedUser: user, canSend: newCanSend));
  }

  /// Update coin amount input
  void updateAmount(int? amount) {
    final newCanSend =
        (amount != null && amount > 0) && (state.selectedUser != null);
    emit(state.copyWith(amount: amount, canSend: newCanSend));
  }

  /// Update optional message input
  void updateMessage(String? message) {
    emit(state.copyWith(message: message));
  }

  /// Verify PIN + send coins
  Future<void> sendTransfer({required String pin}) async {
    if (state.selectedUser == null || state.amount == null) return;

    final recipientUuid = state.selectedUser!.uuid;
    final amount = state.amount!;
    final message = state.message;

    // Save last for retry
    _lastRecipientUuid = recipientUuid;
    _lastAmount = amount;
    _lastMessage = message;
    _lastPin = pin;

    emit(state.copyWith(sending: true, sendError: null, sendSuccess: false));

    try {
      // 1️⃣ Verify PIN
      await repository.verifyPin(pin);

      // 2️⃣ Execute transfer request
      final idempotencyKey = const Uuid().v4();
      await repository.transferCoins(
        toUserUuid: recipientUuid,
        coins: amount,
        reason: message,
        pin: pin,
        idempotencyKey: idempotencyKey,
      );

      // 3️⃣ Refresh balance
      final balance = await repository.getBalance();

      // 4️⃣ Emit success
      emit(
        state.copyWith(
          sending: false,
          sendSuccess: true,
          balance: balance,
          selectedUser: null,
          amount: null,
          message: null,
          canSend: false,
        ),
      );

      // Clear last
      _lastRecipientUuid = null;
      _lastAmount = null;
      _lastMessage = null;
      _lastPin = null;
    } catch (e) {
      emit(
        state.copyWith(
          sending: false,
          sendError: _short(e.toString()),
          sendSuccess: false,
        ),
      );
    }
  }

  /// Retry last transfer
  Future<void> retrySend() async {
    if (_lastRecipientUuid == null || _lastAmount == null || _lastPin == null)
      return;
    await sendTransfer(pin: _lastPin!);
  }

  /// Clear send success flag after showing dialog
  void clearSendSuccess() {
    emit(state.copyWith(sendSuccess: false));
  }

  String _short(String s) {
    if (s.contains('Exception:')) s = s.replaceFirst('Exception:', '');
    return s.trim();
  }
}
