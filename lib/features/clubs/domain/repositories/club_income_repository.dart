import '../entities/club_income_summary.dart';
import '../entities/club_donation.dart';
import '../entities/club_transaction.dart';

abstract class ClubIncomeRepository {
  Future<ClubIncomeSummary> getSummary(String club);
  Future<List<ClubDonation>> getLeaderboard(String club, String period);
  Future<List<ClubTransaction>> getTransactions(String club);
}
