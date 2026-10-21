// lib/features/clubs/presentation/club_coins_ui.dart
//
// Shared bits for the club revamp's paid actions (create a club, join a
// club, enter a room, ask for a camera seat, unlock premium): a confirm
// dialog that states the price up front, and helpers to show the server's
// own message (e.g. "Joining this club costs 10 coins…") instead of a
// generic failure, with a shortcut to top up when coins are short.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/network/interceptors/error_normalizer_interceptor.dart';
import 'package:moonlight/core/routing/route_names.dart';

/// Default fees (mirrors the API's config/clubs.php). Screens that have the
/// server's own value (club profile → joinFeeCoins) use that instead; the
/// API always charges its configured amount and says so on failure.
const int kClubOpeningFeeCoins = 100;
const int kClubJoinFeeCoins = 10;

/// Confirm, then run [join]. Used by every "Join club" button.
Future<void> confirmAndJoinClub(
  BuildContext context, {
  required String clubName,
  required Future<void> Function() join,
  int fee = kClubJoinFeeCoins,
}) async {
  final ok = await confirmCoinSpend(
    context,
    title: 'Join $clubName?',
    coins: fee,
    detail: 'A one-time subscription that goes to the club owner.',
    confirmLabel: 'Join',
  );
  if (ok) await join();
}

/// The server's message for a failed request, or [fallback].
String clubApiMessage(Object e, [String fallback = 'Something went wrong.']) {
  if (e is DioException) {
    final err = e.error;
    if (err is ApiException && err.message.isNotEmpty) return err.message;
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'];
  }
  if (e is ApiException) return e.message;
  return fallback;
}

/// True when the API refused because the wallet is short (HTTP 402).
bool isInsufficientCoins(Object e) {
  if (e is DioException) {
    if (e.response?.statusCode == 402) return true;
    final data = e.response?.data;
    return data is Map && data['code'] == 'INSUFFICIENT_FUNDS';
  }
  return e is ApiException && e.code == 402;
}

/// Asks before spending coins. Returns true when the user confirms.
/// Free actions (coins <= 0) return true without asking.
Future<bool> confirmCoinSpend(
  BuildContext context, {
  required String title,
  required int coins,
  String? detail,
  String confirmLabel = 'Continue',
}) async {
  if (coins <= 0) return true;
  final balance = walletBalance();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF1C1533),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                color: Color(0xFFFFC107),
                size: 26,
              ),
              const SizedBox(width: 6),
              Text(
                '$coins coins',
                style: const TextStyle(
                  color: Color(0xFFFFC107),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 12),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
          ],
          const SizedBox(height: 14),
          // Make the payment visible: what you have, and what's left after.
          FutureBuilder<int?>(
            future: balance,
            builder: (_, snap) {
              final b = snap.data;
              if (snap.connectionState != ConnectionState.done) {
                return const Text(
                  'Checking your wallet…',
                  style: TextStyle(color: Colors.white38, fontSize: 12.5),
                );
              }
              if (b == null) return const SizedBox.shrink();
              final short = b < coins;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: (short ? Colors.redAccent : Colors.white).withValues(
                    alpha: 0.08,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  short
                      ? 'You have $b coins — top up ${coins - b} more to continue.'
                      : 'Your wallet: $b coins → ${b - coins} after paying',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: short ? Colors.redAccent : Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () async {
            final b = await balance;
            if (!c.mounted) return;
            if (b != null && b < coins) {
              // Not enough coins: go top up instead of failing on the server.
              Navigator.of(c).pop(false);
              Navigator.of(context).pushNamed(RouteNames.buyCoins);
              return;
            }
            Navigator.of(c).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7A00),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: FutureBuilder<int?>(
            future: balance,
            builder: (_, snap) => Text(
              snap.data != null && snap.data! < coins ? 'Top up' : confirmLabel,
            ),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}

/// The user's coin balance, or null if it couldn't be loaded.
Future<int?> walletBalance() async {
  try {
    final res = await sl<DioClient>().dio.get('/api/v1/wallet');
    final data = (res.data as Map)['data'] as Map;
    return (data['balance'] as num?)?.toInt();
  } catch (_) {
    return null;
  }
}

/// A clear receipt after a paid action, e.g. "100 coins paid · club created".
void showCoinsPaid(BuildContext context, int coins, String what) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF1C1533),
      content: Row(
        children: [
          const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFC107)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$coins coins paid · $what',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shows why a paid action failed; for a short wallet, offers "Top up".
Future<void> showCoinError(BuildContext context, Object e) async {
  final msg = clubApiMessage(e);
  if (!isInsufficientCoins(e)) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(msg)));
    return;
  }
  final topUp = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF1C1533),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Not enough coins',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, height: 1.45),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Close', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(c).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7A00),
            foregroundColor: Colors.white,
          ),
          child: const Text('Top up'),
        ),
      ],
    ),
  );
  if (topUp == true && context.mounted) {
    Navigator.of(context).pushNamed(RouteNames.buyCoins);
  }
}
