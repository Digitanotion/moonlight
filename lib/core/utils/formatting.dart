import 'package:intl/intl.dart';

String formatCoin(int v) => NumberFormat.decimalPattern().format(v);
String formatNaira(int v) => NumberFormat.currency(symbol: '₦').format(v);
String formatusdint(int v) => NumberFormat.currency(symbol: '\$').format(v);
String formatusd(double v) => NumberFormat.currency(symbol: '\$').format(v);
String convertCoinToUsd(int coin) {
  final usd = 0.01 * coin;
  return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(usd);
}

String convertUsdToCoin(double v) {
  v = ((v / 0.01));
  return v.round().toString();
}

String formatDate(DateTime d) =>
    DateFormat('MMMM d, yyyy \'at\' h:mm a').format(d);

String formatCompact(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final v = (n / 1000.0);
    return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1) + 'K';
  }
  final v = (n / 1000000.0);
  return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1) + 'M';
}

String isoToFlagEmoji(String iso) {
  final up = iso.toUpperCase();
  if (up.length != 2) return '🏳️';
  final int base = 0x1F1E6;
  return String.fromCharCode(base + (up.codeUnitAt(0) - 65)) +
      String.fromCharCode(base + (up.codeUnitAt(1) - 65));
  // sefdf
}
