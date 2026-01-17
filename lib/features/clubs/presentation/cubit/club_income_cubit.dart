import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/club_income_repository.dart';
import 'club_income_state.dart';

class ClubIncomeCubit extends Cubit<ClubIncomeState> {
  final ClubIncomeRepository repo;
  final String club;

  ClubIncomeCubit(this.repo, this.club) : super(const ClubIncomeState());

  Future<void> load({String period = 'all'}) async {
    emit(state.copyWith(loading: true, period: period));

    final summary = await repo.getSummary(club);
    final txs = await repo.getTransactions(club);

    emit(state.copyWith(loading: false, summary: summary, transactions: txs));
  }
}
