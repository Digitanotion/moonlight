import 'package:equatable/equatable.dart';
import '../../domain/entities/club_income_summary.dart';
import '../../domain/entities/club_transaction.dart';

class ClubIncomeState extends Equatable {
  final bool loading;
  final ClubIncomeSummary? summary;
  final List<ClubTransaction> transactions;
  final String period;

  const ClubIncomeState({
    this.loading = false,
    this.summary,
    this.transactions = const [],
    this.period = 'all',
  });

  ClubIncomeState copyWith({
    bool? loading,
    ClubIncomeSummary? summary,
    List<ClubTransaction>? transactions,
    String? period,
  }) {
    return ClubIncomeState(
      loading: loading ?? this.loading,
      summary: summary ?? this.summary,
      transactions: transactions ?? this.transactions,
      period: period ?? this.period,
    );
  }

  @override
  List<Object?> get props => [loading, summary, transactions, period];
}
