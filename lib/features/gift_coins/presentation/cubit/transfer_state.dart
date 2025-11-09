// lib/features/gift_coins/presentation/cubit/transfer_state.dart
part of 'transfer_cubit.dart';

class TransferState extends Equatable {
  final bool loading;
  final int balance;

  final bool searchLoading;
  final String? searchQuery;
  final String? searchError;
  final List<GiftUser> searchResults;

  final bool sending;
  final bool sendSuccess;
  final String? sendError;
  final String? error;

  final GiftUser? selectedUser;
  final int? amount;
  final String? message;
  final bool canSend;

  const TransferState({
    required this.loading,
    required this.balance,
    required this.searchLoading,
    this.searchQuery,
    this.searchError,
    required this.searchResults,
    required this.sending,
    required this.sendSuccess,
    this.sendError,
    this.error,
    this.selectedUser,
    this.amount,
    this.message,
    required this.canSend,
  });

  factory TransferState.initial() => const TransferState(
    loading: false,
    balance: 0,
    searchLoading: false,
    searchQuery: null,
    searchError: null,
    searchResults: [],
    sending: false,
    sendSuccess: false,
    sendError: null,
    error: null,
    selectedUser: null,
    amount: null,
    message: null,
    canSend: false,
  );

  TransferState copyWith({
    bool? loading,
    int? balance,
    bool? searchLoading,
    String? searchQuery,
    String? searchError,
    List<GiftUser>? searchResults,
    bool? sending,
    bool? sendSuccess,
    String? sendError,
    String? error,
    GiftUser? selectedUser,
    int? amount,
    String? message,
    bool? canSend,
  }) {
    return TransferState(
      loading: loading ?? this.loading,
      balance: balance ?? this.balance,
      searchLoading: searchLoading ?? this.searchLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      searchError: searchError ?? this.searchError,
      searchResults: searchResults ?? this.searchResults,
      sending: sending ?? this.sending,
      sendSuccess: sendSuccess ?? this.sendSuccess,
      sendError: sendError ?? this.sendError,
      error: error ?? this.error,
      selectedUser: selectedUser ?? this.selectedUser,
      amount: amount ?? this.amount,
      message: message ?? this.message,
      canSend: canSend ?? this.canSend,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    balance,
    searchLoading,
    searchQuery,
    searchError,
    searchResults,
    sending,
    sendSuccess,
    sendError,
    error,
    selectedUser,
    amount,
    message,
    canSend,
  ];
}
