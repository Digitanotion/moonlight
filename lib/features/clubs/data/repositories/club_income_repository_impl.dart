import '../../domain/entities/club_donation.dart';
import '../../domain/entities/club_income_summary.dart';
import '../../domain/entities/club_transaction.dart';
import '../../domain/repositories/club_income_repository.dart';
import '../datasources/club_income_remote_data_source.dart';

class ClubIncomeRepositoryImpl implements ClubIncomeRepository {
  final ClubIncomeRemoteDataSource remote;
  ClubIncomeRepositoryImpl(this.remote);

  @override
  Future<ClubIncomeSummary> getSummary(
    String club, {
    String period = 'all',
  }) async {
    final data = await remote.getStats(club, period: period);
    return ClubIncomeSummary.fromJson(data['summary']);
  }

  @override
  Future<List<ClubDonation>> getLeaderboard(String club, String period) async {
    final data = await remote.getStats(club, period: period);
    final items = data['leaderboard']['items'] as List;
    return items.map((e) => ClubDonation.fromJson(e)).toList();
  }

  @override
  Future<List<ClubTransaction>> getTransactions(
    String club, {
    String period = 'all', // ← NEW
  }) async {
    final list = await remote.getTransactions(club, period: period);
    return list.map((e) => ClubTransaction.fromJson(e)).toList();
  }
}
