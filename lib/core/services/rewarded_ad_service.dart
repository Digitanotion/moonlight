// lib/core/services/rewarded_ad_service.dart
//
// "Free coins · watch ads" in livestreams: a Google AdMob rewarded ad,
// preloaded so it opens instantly. The coins are NOT added by the app —
// AdMob calls our server (server-side verification, signed by Google) and
// the server credits the wallet. The app only tells AdMob who is watching
// (ServerSideVerificationOptions.userId = the user's uuid).

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:moonlight/core/services/ad_service.dart';

class RewardedAdService {
  RewardedAdService._();
  static final RewardedAdService instance = RewardedAdService._();

  // Google's always-fill test units in debug builds.
  static const _testUnit = {
    'android': 'ca-app-pub-3940256099942544/5224354917',
    'ios': 'ca-app-pub-3940256099942544/1712485313',
  };

  // Real rewarded ad units — create them in AdMob (ad format "Rewarded"),
  // turn on server-side verification with the callback URL
  // https://svc.moonlightstream.app/api/v1/ads/admob/ssv, then paste here.
  static const _prodUnit = {
    'android': 'REPLACE_WITH_REWARDED_UNIT_ID',
    'ios': 'REPLACE_WITH_REWARDED_UNIT_ID',
  };

  String get _unitId {
    final table = kDebugMode ? _testUnit : _prodUnit;
    return table[Platform.isIOS ? 'ios' : 'android']!;
  }

  bool get configured => !_unitId.startsWith('REPLACE');

  RewardedAd? _ad;
  bool _loading = false;
  int _retry = 0;

  /// Ready to show right now (no waiting).
  final ValueNotifier<bool> ready = ValueNotifier(false);

  /// Load one ad in the background (call when a livestream opens and after
  /// each ad).
  Future<void> preload() async {
    if (!configured || _ad != null || _loading) return;
    await AdService.instance.ready;
    _loading = true;
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _retry = 0;
          _ad = ad;
          ready.value = true;
        },
        onAdFailedToLoad: (err) {
          _loading = false;
          ready.value = false;
          debugPrint('⚠️ [RewardedAd] load failed: $err');
          // Back off: 5s, 10s, 20s … up to ~2 min.
          final wait = Duration(seconds: (5 << _retry.clamp(0, 5)));
          _retry++;
          Timer(wait, preload);
        },
      ),
    );
  }

  /// Show the ad. [onEarned] runs once the viewer has watched enough to be
  /// rewarded (the server credits the coins a moment later).
  /// Returns false when no ad was available.
  Future<bool> show({
    required String userUuid,
    String? customData,
    required VoidCallback onEarned,
    VoidCallback? onClosed,
  }) async {
    final ad = _ad;
    if (ad == null) {
      unawaited(preload());
      return false;
    }
    _ad = null;
    ready.value = false;

    await ad.setServerSideOptions(
      ServerSideVerificationOptions(userId: userUuid, customData: customData),
    );
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onClosed?.call();
        preload(); // next one ready for the next tap
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('⚠️ [RewardedAd] show failed: $err');
        ad.dispose();
        onClosed?.call();
        preload();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => onEarned());
    return true;
  }
}
