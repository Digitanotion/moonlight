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

  // Track pending purchases to prevent duplicate processing
  final Set<String> _processingPurchases = {};

  PlayBillingService({
    required WalletRepositoryImpl repo,
    required IdempotencyHelper idem,
  }) : _repo = repo,
       _idem = idem;

  // ─────────────────────────────────────────────
  // Public getters
  // ─────────────────────────────────────────────

  /// Whether Google Play Billing is available on this device.
  /// Always false until [init] has completed successfully.
  bool get isAvailable => _isAvailable;

  /// Whether [init] has been called and finished (regardless of outcome).
  bool get isInitialized => _isInitialized;

  // ─────────────────────────────────────────────
  // Init
  // ─────────────────────────────────────────────

  /// Must be awaited before calling [buyAndComplete].
  /// Safe to call multiple times — re-runs the availability check each time.
  Future<void> init() async {
    debugPrint('🔍 ===== PLAY BILLING INIT =====');

    try {
      // 1. Check billing availability
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

      // 2. Confirm Android platform addition is accessible
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
          debugPrint('✅ Android platform addition available');
        } catch (e) {
          debugPrint('ℹ️  Android platform addition unavailable: $e');
        }
      }

      // 3. Probe connection with a lightweight product query
      try {
        final probe = await _iap.queryProductDetails({'__probe__'});
        debugPrint(
          '📦 Billing connection probe — '
          'error: ${probe.error?.message ?? "none"}, '
          'products: ${probe.productDetails.length}',
        );
      } catch (e) {
        // A failed probe only means the dummy SKU doesn't exist — billing
        // itself is still reachable.
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

  // ─────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  // ─────────────────────────────────────────────
  // Main purchase entry point
  // ─────────────────────────────────────────────

  /// Full end-to-end purchase flow:
  ///   1. Query product from Play
  ///   2. Launch billing sheet
  ///   3. Receive purchase token
  ///   4. Verify with your backend
  ///   5. Acknowledge with Google Play
  ///
  /// Returns [TransactionModel] on success, `null` if the user cancelled.
  /// Throws on any other error.
  Future<TransactionModel?> buyAndComplete({
    required String productId,
    String? packageCode,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    // ── Guard: init must have run ──────────────────────────────────────────
    if (!_isInitialized) {
      debugPrint(
        '⚠️  buyAndComplete called before init() finished — running init now',
      );
      await init();
    }

    if (!_isAvailable) {
      throw Exception(
        'Google Play Billing is not available on this device. '
        'Make sure the app was installed from the Play Store and that '
        'Google Play Services are up to date.',
      );
    }

    // ── Guard: no concurrent purchases ────────────────────────────────────
    if (_isPurchasing) {
      debugPrint('⚠️  Purchase already in progress');
      throw Exception('A purchase is already in progress. Please wait.');
    }

    _isPurchasing = true;
    _subscription?.cancel();

    final completer = Completer<TransactionModel?>();

    try {
      // 1. Query product details
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

      // 2. Generate & persist idempotency key
      final idempotencyKey = _idem.generateKey();
      await _idem.persist(idempotencyKey, {
        'productId': productId,
        'packageCode': packageCode,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('🔑 Idempotency key: $idempotencyKey');

      // 3. Subscribe to purchase stream BEFORE launching the billing sheet
      _subscription = _iap.purchaseStream.listen(
        (purchases) => _handlePurchaseUpdates(
          purchases,
          completer,
          productId,
          idempotencyKey,
          packageCode,
        ),
        onError: (Object error) {
          debugPrint('❌ Purchase stream error: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        cancelOnError: false,
      );

      // 4. Launch the billing sheet
      debugPrint('💰 Launching billing sheet for: $productId');
      final purchaseParam = PurchaseParam(productDetails: productDetails);
      final launched = await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: false, // We acknowledge only after server verification
      );

      if (!launched) {
        throw Exception(
          'Failed to launch the Google Play billing sheet for "$productId".',
        );
      }

      // 5. Wait for the purchase stream to resolve (or time out)
      final result = await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            'Purchase timed out after ${timeout.inSeconds}s. '
            'The Play billing sheet may still be open.',
            timeout,
          );
        },
      );

      return result;
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
  // Purchase stream handler
  // ─────────────────────────────────────────────

  void _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
    Completer<TransactionModel?> completer,
    String expectedProductId,
    String idempotencyKey,
    String? packageCode,
  ) {
    for (final purchase in purchases) {
      // Only handle our expected product
      if (purchase.productID != expectedProductId) continue;

      // Deduplicate — same purchase can arrive multiple times
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
              )
              .then((_) {
                _processingPurchases.remove(purchaseKey);
              })
              .catchError((Object error) {
                _processingPurchases.remove(purchaseKey);
                if (!completer.isCompleted) {
                  completer.completeError(error);
                }
              });
          break;

        case PurchaseStatus.error:
          final msg = purchase.error?.message ?? 'Unknown purchase error';
          debugPrint('❌ Purchase error from Play: $msg');
          _processingPurchases.remove(purchaseKey);
          if (!completer.isCompleted) {
            completer.completeError(Exception(msg));
          }
          // Always complete/acknowledge errored purchases to avoid them
          // being re-delivered indefinitely.
          _iap
              .completePurchase(purchase)
              .catchError(
                (Object e) =>
                    debugPrint('⚠️  completePurchase (error) threw: $e'),
              );
          break;

        case PurchaseStatus.pending:
          // Pending = payment method delayed (e.g. cash payment kiosks).
          // Do nothing — wait for a future update.
          debugPrint('⏳ Purchase pending — waiting for final status');
          _processingPurchases.remove(purchaseKey);
          break;

        case PurchaseStatus.canceled:
          debugPrint('🚫 Purchase cancelled by user');
          _processingPurchases.remove(purchaseKey);
          if (!completer.isCompleted) {
            completer.complete(null); // null = user-cancelled, not an error
          }
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

      // ── Server verification ────────────────────────────────────────────
      debugPrint('🔐 Verifying purchase with backend…');
      final transaction = await _repo.purchaseWithToken(
        productId: productId,
        purchaseToken: purchaseToken,
        packageCode: packageCode,
        idempotencyKey: idempotencyKey,
      );
      debugPrint('✅ Backend verification successful');

      // ── Mark idempotency key as done ───────────────────────────────────
      await _idem.complete(idempotencyKey);

      // ── Acknowledge with Google Play ───────────────────────────────────
      // Must happen within 3 days or Google will refund automatically.
      try {
        await _iap.completePurchase(purchase);
        debugPrint('✅ Purchase acknowledged with Google Play');
      } catch (e) {
        // Server already credited the user — log but do not fail.
        // The purchase will be re-delivered and can be re-acknowledged.
        debugPrint('⚠️  completePurchase threw (non-fatal): $e');
      }

      // ── Clear from local pending list ──────────────────────────────────
      await _clearPendingPurchase(idempotencyKey);

      if (!completer.isCompleted) {
        completer.complete(transaction);
      }
    } catch (e) {
      debugPrint('❌ Server verification failed: $e');
      // Do NOT acknowledge — keeps the purchase deliverable for retry.
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
  }

  // ─────────────────────────────────────────────
  // Pending purchase persistence (local fallback)
  // ─────────────────────────────────────────────

  Future<void> _savePendingPurchase(
    String idempotencyKey,
    String productId,
    String? packageCode,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_purchases') ?? [];
      pending.add(
        jsonEncode({
          'idempotency_key': idempotencyKey,
          'product_id': productId,
          'package_code': packageCode,
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
          return true; // keep malformed entries rather than silently dropping
        }
      }).toList();
      await prefs.setStringList('pending_purchases', filtered);
    } catch (e) {
      debugPrint('⚠️  Failed to clear pending purchase locally: $e');
    }
  }

  // ─────────────────────────────────────────────
  // Retry pending purchases (call on app resume)
  // ─────────────────────────────────────────────

  /// Call this when the app resumes (e.g. in [WidgetsBindingObserver.didChangeAppLifecycleState])
  /// to re-attempt server verification for any purchases that completed on
  /// the Play side but whose server call previously failed.
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
          debugPrint('🔄 Retrying pending purchase: $data');
          // TODO: implement a restore-by-token flow if your backend supports it.
          // For now we log; the purchase stream will re-deliver unacknowledged
          // purchases automatically on next app launch.
        } catch (e) {
          debugPrint('⚠️  Failed to parse pending purchase entry: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️  retryPendingPurchases failed: $e');
    }
  }
}
