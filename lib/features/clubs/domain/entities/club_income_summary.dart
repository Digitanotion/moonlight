class ClubIncomeSummary {
  final int today;
  final int last7Days;
  final int thisMonth;
  final int lastMonth;
  final int allTime;
  final int growthPercent;

  ClubIncomeSummary({
    required this.today,
    required this.last7Days,
    required this.thisMonth,
    required this.lastMonth,
    required this.allTime,
    required this.growthPercent,
  });

  factory ClubIncomeSummary.fromJson(Map<String, dynamic> json) {
    return ClubIncomeSummary(
      today: json['today'] ?? 0,
      last7Days: json['last_7_days'] ?? 0,
      thisMonth: json['this_month'] ?? 0,
      lastMonth: json['last_month'] ?? 0,
      allTime: json['all_time'] ?? 0,
      growthPercent: json['growth_percent'] ?? 0,
    );
  }
}
