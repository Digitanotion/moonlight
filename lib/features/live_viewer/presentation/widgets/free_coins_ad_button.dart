// lib/features/live_viewer/presentation/widgets/free_coins_ad_button.dart
//
// "Free coins · watch ads" pill above the Join button in a livestream.
// Opens a (preloaded) Google rewarded ad; the server credits the coins when
// AdMob confirms the ad was watched.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show LoadAdError;
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/rewarded_ad_service.dart';
import 'package:moonlight/widgets/top_snack.dart';

/// Shows a rewarded ad and, once it's watched, tells the user what it
/// earned. Used by the live's "Free coins" pill and the short-video feed.
/// Completes when the ad closes (or right away when none is ready).
Future<void> watchRewardedAd(BuildContext context, {String? customData}) async {
  final ads = RewardedAdService.instance;
  final uuid = sl<CurrentUserService>().getCurrentUserId();
  if (uuid == null) return;
  // How many ads the server has confirmed so far — compared after the ad
  // so we only say "you earned" once AdMob's confirmation really landed.
  final before = await _rewardStatus();
  // Nothing loaded yet: load now and wait a few seconds rather than send
  // the user away with "try again" (the caller shows a spinner meanwhile).
  if (!await ads.waitUntilReady()) {
    if (context.mounted) TopSnack.info(context, _noAdMessage(ads.lastError));
    return;
  }
  final done = Completer<void>();
  var earned = false;
  final shown = await ads.show(
    userUuid: uuid,
    customData: customData,
    onEarned: () => earned = true,
    onClosed: () {
      if (!done.isCompleted) done.complete();
      if (earned && context.mounted) {
        _thank(context, (before?['ads_watched'] as num?)?.toInt());
      }
    },
  );
  if (!shown) {
    if (context.mounted) TopSnack.info(context, _noAdMessage(ads.lastError));
    return;
  }
  await done.future;
}

String _noAdMessage(LoadAdError? err) {
  if (err?.code == 3) {
    // Google had no ad to give right now.
    return 'No ads available right now — please try again a bit later.';
  }
  if (err?.code == 2) {
    return 'Couldn\'t load an ad — check your internet connection and try again.';
  }
  return 'Couldn\'t load an ad right now — please try again in a minute.';
}

Future<Map?> _rewardStatus() async {
  try {
    final r = await sl<DioClient>().dio.get('/api/v1/ads/rewarded/status');
    return r.data is Map ? r.data as Map : null;
  } catch (_) {
    return null;
  }
}

/// AdMob tells our server a few seconds after the ad. Wait for that, then
/// say what it earned. With 0.2 coins per ad, every 5th ad pays 1 coin.
/// If the confirmation hasn't arrived, say so honestly instead of
/// claiming a coin (that's what made users look for coins that weren't
/// there).
Future<void> _thank(BuildContext context, int? watchedBefore) async {
  Map? d;
  var confirmed = false;
  for (final wait in const [3, 4, 6]) {
    await Future.delayed(Duration(seconds: wait));
    d = await _rewardStatus();
    final now = (d?['ads_watched'] as num?)?.toInt();
    if (now != null && watchedBefore != null && now > watchedBefore) {
      confirmed = true;
      break;
    }
    // Older server without ads_watched: can't tell — fall back below.
    if (now == null) break;
  }

  var msg =
      'Thanks for watching! Your reward is being confirmed — it '
      'can take a few minutes to show in your wallet.';
  final perCoin = (d?['ads_per_coin'] as num?)?.toInt() ?? 1;
  final toNext = (d?['ads_to_next_coin'] as num?)?.toInt() ?? 1;
  final left = (d?['remaining_today'] as num?)?.toInt();
  if (confirmed) {
    if (perCoin <= 1) {
      msg = 'You earned free coins! Check your wallet.';
    } else if (toNext == perCoin) {
      msg =
          'You earned 1 coin! It\'s in your wallet. '
          'Watch $perCoin more ads for the next one.';
    } else {
      msg =
          'Ad counted! $toNext more '
          '${toNext == 1 ? 'ad' : 'ads'} to earn your next coin.';
    }
  } else if (left == 0) {
    msg =
        'You\'ve reached today\'s limit for free-coin ads. '
        'Come back tomorrow!';
  }
  if (confirmed && left == 0) msg += ' That\'s all the ads for today.';
  if (context.mounted) TopSnack.success(context, msg);
}

class FreeCoinsAdButton extends StatefulWidget {
  /// Sent with the reward (shows up on the server as e.g. "live:3374").
  final String? customData;
  const FreeCoinsAdButton({super.key, this.customData});

  @override
  State<FreeCoinsAdButton> createState() => _FreeCoinsAdButtonState();
}

class _FreeCoinsAdButtonState extends State<FreeCoinsAdButton> {
  final _ads = RewardedAdService.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ads.preload();
  }

  Future<void> _watch() async {
    if (_busy) return;
    setState(() => _busy = true);
    await watchRewardedAd(context, customData: widget.customData);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ads.configured) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: _ads.ready,
      builder: (_, ready, _) => GestureDetector(
        onTap: _watch,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: ready ? 1 : 0.7,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC24B), Color(0xFFFF8A00)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8A00).withValues(alpha: 0.45),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Free coins',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'watch ads',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
