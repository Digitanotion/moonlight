// lib/features/wallet/services/play_billing_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/wallet_repository_impl.dart';
import '../domain/models/transaction_model.dart';
import 'idempotency_helper.dart';

class PlayBillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final WalletRepositoryImpl _repo;
  final IdempotencyHelper _idem;
  final Uuid _uuid = const Uuid();

  bool _isAvailable = false;
  bool _isInitialized = false;
  bool _isPurchasing = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final Set<String> _processingPurchases = {};

  PlayBillingService({
    required WalletRepositoryImpl repo,
    required IdempotencyHelper idem,
  }) : _repo = repo,
       _idem = idem;

  bool get isAvailable => _isAvailable;
  bool get isInitialized => _isInitialized;

  // ─────────────────────────────────────────────
  // Init
  // ─────────────────────────────────────────────

  Future<void> init() async {
    debugPrint('🔍 ===== PLAY BILLING INIT =====');
    try {
      _isAvailable = await _iap.isAvailable();
      debugPrint('📱 Billing available: $_isAvailable');

      if (!_isAvailable) {
        debugPrint('⚠️  BILLING NOT AVAILABLE — Possible causes:');
        debugPrint('   1. App not installed from Play Store (sideloaded?)');
        debugPrint('   2. Wrong Google account signed into Play Store');
        debugPrint('   3. Play Services needs an update');
        debugPrint('   4. BILLING permission missing from merged manifest');
        debugPrint('   5. Device/region restriction');
        _isInitialized = true;
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
          debugPrint('✅ Android platform addition available');
        } catch (e) {
          debugPrint('ℹ️  Android platform addition unavailable: $e');
        }
      }

      try {
        final probe = await _iap.queryProductDetails({'__probe__'});
        debugPrint(
          '📦 Billing connection probe — '
          'error: ${probe.error?.message ?? "none"}, '
          'products: ${probe.productDetails.length}',
        );
      } catch (e) {
        debugPrint('📦 Probe query threw (expected for dummy SKU): $e');
      }

      debugPrint('✅ PlayBillingService initialised successfully');
    } catch (e) {
      debugPrint('❌ Billing initialisation error: $e');
      _isAvailable = false;
    } finally {
      _isInitialized = true;
      debugPrint('🔍 ===== END PLAY BILLING INIT =====');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  // ─────────────────────────────────────────────
  // Main purchase entry point
  // ─────────────────────────────────────────────

  Future<TransactionModel?> buyAndComplete({
    required String productId,
    String? packageCode,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (!_isInitialized) {
      debugPrint('⚠️  buyAndComplete called before init() — running init now');
      await init();
    }

    if (!_isAvailable) {
      throw Exception(
        'Google Play Billing is not available on this device. '
        'Make sure the app was installed from the Play Store and that '
        'Google Play Services are up to date.',
      );
    }

    if (_isPurchasing) {
      debugPrint('⚠️  Purchase already in progress');
      throw Exception('A purchase is already in progress. Please wait.');
    }

    _isPurchasing = true;
    _subscription?.cancel();

    final completer = Completer<TransactionModel?>();

    try {
      // 1. Query product from Play — this gives us the authoritative price
      debugPrint('🔍 Querying product: $productId');
      final productResponse = await _iap.queryProductDetails({productId});

      if (productResponse.error != null) {
        throw Exception(
          'Failed to query product "$productId": ${productResponse.error!.message}',
        );
      }
      if (productResponse.productDetails.isEmpty) {
        throw Exception(
          'Product "$productId" not found in Play Console. '
          'Ensure the SKU is Active and the app version has been submitted '
          'to at least the Internal Testing track.',
        );
      }

      final productDetails = productResponse.productDetails.first;
      debugPrint(
        '✅ Product found: ${productDetails.title} — ${productDetails.price}',
      );

      // ✅ Extract the authoritative USD price from Google Play.
      // priceAmountMicros is always in the currency the product was priced in
      // on Play Console (USD). It is NOT the user's local display price.
      // 1 USD = 1,000,000 micros = 100 cents → cents = micros / 10,000
      //   $0.99  →  990,000 micros →  99 cents
      //   $4.99  → 4,990,000 micros → 499 cents
      final double priceUsdCents = _extractPriceUsdCents(productDetails);
      debugPrint(
        '💵 Price from Play: $priceUsdCents cents '
        '(\$${(priceUsdCents / 100).toStringAsFixed(2)})',
      );

      // 2. Generate & persist idempotency key
      final idempotencyKey = _idem.generateKey();
      await _idem.persist(idempotencyKey, {
        'productId': productId,
        'packageCode': packageCode,
        'priceUsdCents': priceUsdCents,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('🔑 Idempotency key: $idempotencyKey');

      // 3. Subscribe BEFORE launching the billing sheet
      _subscription = _iap.purchaseStream.listen(
        (purchases) => _handlePurchaseUpdates(
          purchases,
          completer,
          productId,
          idempotencyKey,
          packageCode,
          priceUsdCents, // ✅ price flows all the way to the server call
        ),
        onError: (Object error) {
          debugPrint('❌ Purchase stream error: $error');
          if (!completer.isCompleted) completer.completeError(error);
        },
        cancelOnError: false,
      );

      // 4. Launch billing sheet
      debugPrint('💰 Launching billing sheet for: $productId');
      final purchaseParam = PurchaseParam(productDetails: productDetails);
      final launched = await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: false, // server consumes after verification
      );

      if (!launched) {
        throw Exception(
          'Failed to launch the Google Play billing sheet for "$productId".',
        );
      }

      // 5. Wait for result
      return await completer.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException(
          'Purchase timed out after ${timeout.inSeconds}s. '
          'The Play billing sheet may still be open.',
          timeout,
        ),
      );
    } catch (e) {
      debugPrint('❌ Purchase failed: $e');
      rethrow;
    } finally {
      _isPurchasing = false;
      await _subscription?.cancel();
      _subscription = null;
    }
  }

  // ─────────────────────────────────────────────
  // Price extraction
  // ─────────────────────────────────────────────

  /// Extracts the product price in USD cents from Google Play's ProductDetails.
  ///
  /// Primary method: AndroidProductDetails.skuDetails.priceAmountMicros
  ///   — This is the price exactly as set in Play Console in USD micros.
  ///   — Always USD regardless of the user's country/currency display.
  ///
  /// Fallback: parse the formatted price string (e.g. "$0.99")
  ///   — Less reliable for non-USD locales, but better than returning 0.
  double _extractPriceUsdCents(ProductDetails productDetails) {
    // Primary: Android SkuDetails (most accurate)
    if (productDetails is GooglePlayProductDetails) {
      try {
        final micros = productDetails.rawPrice;
        final cents = (micros / 10000);
        debugPrint('💵 priceAmountMicros: $micros → $cents cents');
        return cents;
      } catch (e) {
        debugPrint('⚠️  skuDetails.priceAmountMicros failed: $e');
      }
    }

    // Fallback: parse formatted price string e.g. "$0.99", "US$4.99"
    try {
      final digits = productDetails.price.replaceAll(RegExp(r'[^\d.]'), '');
      final dollars = double.tryParse(digits) ?? 0.0;
      final cents = (dollars * 100);
      debugPrint(
        '💵 Fallback price from "${productDetails.price}" → $cents cents',
      );
      return cents;
    } catch (e) {
      debugPrint('⚠️  Price string parse failed: $e');
    }

    debugPrint(
      '⚠️  Could not determine price — returning 0 (server will use DB fallback)',
    );
    return 0;
  }

  // ─────────────────────────────────────────────
  // Purchase stream handler
  // ─────────────────────────────────────────────

  void _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
    Completer<TransactionModel?> completer,
    String expectedProductId,
    String idempotencyKey,
    String? packageCode,
    double priceUsdCents, // ✅ carried through
  ) {
    for (final purchase in purchases) {
      if (purchase.productID != expectedProductId) continue;

      final purchaseKey = '${purchase.purchaseID}_${purchase.productID}';
      if (_processingPurchases.contains(purchaseKey)) {
        debugPrint('⚠️  Already processing: $purchaseKey — skipping');
        continue;
      }
      _processingPurchases.add(purchaseKey);

      debugPrint(
        '📦 Purchase update — status: ${purchase.status.name}, '
        'product: ${purchase.productID}',
      );

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(
                purchase,
                completer,
                idempotencyKey,
                packageCode,
                priceUsdCents, // ✅ passed to server
              )
              .then((_) {
                _processingPurchases.remove(purchaseKey);
              })
              .catchError((Object error) {
                _processingPurchases.remove(purchaseKey);
                if (!completer.isCompleted) completer.completeError(error);
              });
          break;

        case PurchaseStatus.error:
          final msg = purchase.error?.message ?? 'Unknown purchase error';
          debugPrint('❌ Purchase error from Play: $msg');
          _processingPurchases.remove(purchaseKey);
          if (!completer.isCompleted) completer.completeError(Exception(msg));
          _iap
              .completePurchase(purchase)
              .catchError(
                (Object e) =>
                    debugPrint('⚠️  completePurchase (error) threw: $e'),
              );
          break;

        case PurchaseStatus.pending:
          debugPrint('⏳ Purchase pending — waiting for final status');
          _processingPurchases.remove(purchaseKey);
          break;

        case PurchaseStatus.canceled:
          debugPrint('🚫 Purchase cancelled by user');
          _processingPurchases.remove(purchaseKey);
          if (!completer.isCompleted) completer.complete(null);
          _iap
              .completePurchase(purchase)
              .catchError(
                (Object e) =>
                    debugPrint('⚠️  completePurchase (cancel) threw: $e'),
              );
          break;
      }
    }
  }

  // ─────────────────────────────────────────────
  // Server verification + acknowledgement
  // ─────────────────────────────────────────────

  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchase,
    Completer<TransactionModel?> completer,
    String idempotencyKey,
    String? packageCode,
    double priceUsdCents, // ✅ sent to backend
  ) async {
    try {
      if (purchase is! GooglePlayPurchaseDetails) {
        throw Exception(
          'Unexpected purchase type: ${purchase.runtimeType}. '
          'Only GooglePlayPurchaseDetails is supported.',
        );
      }

      final purchaseToken = purchase.billingClientPurchase.purchaseToken;
      final productId = purchase.productID;

      debugPrint('✅ Raw purchase received — token: $purchaseToken');
      debugPrint('💵 Sending price to server: $priceUsdCents cents');

      // Verify with backend — price_usd_cents tells server how many coins to credit
      final transaction = await _repo.purchaseWithToken(
        productId: productId,
        purchaseToken: purchaseToken,
        priceUsdCents: priceUsdCents, // ✅ server: coins = priceUsdCents / 0.01
        packageCode: packageCode,
        idempotencyKey: idempotencyKey,
      );
      debugPrint('✅ Backend verification successful');

      await _idem.complete(idempotencyKey);

      // Acknowledge with Google Play (non-fatal if it fails)
      try {
        await _iap.completePurchase(purchase);
        debugPrint('✅ Purchase acknowledged with Google Play');
      } catch (e) {
        debugPrint('⚠️  completePurchase threw (non-fatal): $e');
      }

      await _clearPendingPurchase(idempotencyKey);

      if (!completer.isCompleted) completer.complete(transaction);
    } catch (e) {
      debugPrint('❌ Server verification failed: $e');
      // Do NOT acknowledge — keeps purchase deliverable for retry
      if (!completer.isCompleted) completer.completeError(e);
    }
  }

  // ─────────────────────────────────────────────
  // Pending purchase persistence
  // ─────────────────────────────────────────────

  Future<void> _savePendingPurchase(
    String idempotencyKey,
    String productId,
    String? packageCode,
    int priceUsdCents,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_purchases') ?? [];
      pending.add(
        jsonEncode({
          'idempotency_key': idempotencyKey,
          'product_id': productId,
          'package_code': packageCode,
          'price_usd_cents': priceUsdCents,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      await prefs.setStringList('pending_purchases', pending);
    } catch (e) {
      debugPrint('⚠️  Failed to save pending purchase locally: $e');
    }
  }

  Future<void> _clearPendingPurchase(String idempotencyKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_purchases') ?? [];
      final filtered = pending.where((item) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          return map['idempotency_key'] != idempotencyKey;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList('pending_purchases', filtered);
    } catch (e) {
      debugPrint('⚠️  Failed to clear pending purchase locally: $e');
    }
  }

  /// Call on app resume to retry any purchases whose server call failed.
  /// The purchase stream will also re-deliver unacknowledged purchases
  /// automatically on next app launch.
  Future<void> retryPendingPurchases() async {
    if (!_isAvailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_purchases') ?? [];
      if (pending.isEmpty) return;
      debugPrint('🔄 Found ${pending.length} pending purchase(s) — retrying…');
      for (final item in pending) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          debugPrint('🔄 Pending purchase data: $data');
          // Purchase stream re-delivers unacknowledged purchases on next launch.
          // For explicit retry, call buyAndComplete() with the same productId.
        } catch (e) {
          debugPrint('⚠️  Failed to parse pending purchase entry: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️  retryPendingPurchases failed: $e');
    }
  }
}
