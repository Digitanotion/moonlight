class LiveEndAnalytics {
  final String status; // "ended"
  final String? endedAtIso; // may be null (server time)
  final String durationFormatted; // e.g. "19:39:59"
  final double durationSeconds; // from API
  final int totalViewers;
  final int totalChats;
  final int coinsAmount; // e.g. 12980
  final String coinsCurrency; // "coins"

  const LiveEndAnalytics({
    required this.status,
    required this.endedAtIso,
    required this.durationFormatted,
    required this.durationSeconds,
    required this.totalViewers,
    required this.totalChats,
    required this.coinsAmount,
    required this.coinsCurrency,
  });
}
