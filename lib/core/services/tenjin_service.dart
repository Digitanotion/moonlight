// lib/core/services/tenjin_service.dart
//
// Tenjin SDK integration for Moonlight Stream.
// Replace TENJIN_SDK_KEY_PLACEHOLDER with your actual key from:
// https://www.tenjin.io/dashboard/organizations

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tenjin_plugin/tenjin_sdk.dart';

class TenjinService {
  TenjinService._();

  static const String _sdkKey = 'NLUEOH5AXYRW7XMUZVYMSYF64ZIQL7QS';
  static final TenjinSDK _sdk = TenjinSDK.instance;
  static bool _initialized = false;

  // ── Initialization — call once in main() ────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Use initialize(sdkKey:) — init(apiKey:) is deprecated
    _sdk.initialize(sdkKey: _sdkKey);

    // Register for SKAdNetwork postbacks (iOS only)
    if (Platform.isIOS) {
      _sdk.registerAppForAdNetworkAttribution();
      // Request ATT permission BEFORE connect() so IDFA is available
      await _sdk.requestTrackingAuthorization();
    }

    // connect() must be called on EVERY app launch, not just first launch.
    // Tenjin may suspend accounts that only call connect on first open.
    _sdk.connect();
// Print everything needed for Tenjin test device registration
final analyticsId = await _sdk.getAnalyticsInstallationId();
debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
debugPrint('TENJIN TEST DEVICE SETUP');
debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
debugPrint('App: Moonlight Livestream App');
debugPrint('Analytics Installation ID: $analyticsId');
debugPrint('Platform: ${Platform.operatingSystem}');
debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
debugPrint('For Google Advertising ID: Settings → Google → Ads → Advertising ID');
debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  

  // ── Custom events ────────────────────────────────────────────────────────
  // Only call these AFTER initialize() has been called.

  /// User opened a live stream
  static void trackLiveStreamOpened() =>
      _sdk.eventWithName('live_stream_opened');

  /// User scrolled to a new stream in the viewer
  static void trackLiveStreamScrolled() =>
      _sdk.eventWithName('live_stream_scrolled');

  /// User promoted to co-host (guest mode)
  static void trackGuestModeEntered() =>
      _sdk.eventWithName('guest_mode_entered');

  /// User sent a gift — pass coin value
  static void trackGiftSent(int coinValue) =>
      _sdk.eventWithNameAndValue('gift_sent', coinValue);

  /// User purchased coins
  static void trackCoinsPurchased(int coinAmount) =>
      _sdk.eventWithNameAndValue('coins_purchased', coinAmount);

  /// User created a post
  static void trackPostCreated() => _sdk.eventWithName('post_created');

  /// User joined a club
  static void trackClubJoined() => _sdk.eventWithName('club_joined');

  /// User registered a new account
  static void trackRegistration() => _sdk.eventWithName('registration');

  // ── AdMob ILRD — impression level ad revenue ──────────────────────────
  // NOTE: ILRD is a paid Tenjin feature. Contact your account manager first.

  static void trackAdMobImpression({
    required String adUnitId,
    required int valueMicros,
    required String currencyCode,
    required int precisionType,
  }) {
    _sdk.eventAdImpressionAdMob({
      'ad_unit_id': adUnitId,
      'value_micros': valueMicros,
      'currency_code': currencyCode,
      'precision_type': precisionType,
    });
  }
}