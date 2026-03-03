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
import 'idempotency_helper.dart'; // 👈 Add this import

class PlayBillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final WalletRepositoryImpl _repo;
  final IdempotencyHelper _idem; // 👈 Add this
  final Uuid _uuid = const Uuid();

  bool _isAvailable = false;
  bool _isPurchasing = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Track pending purchases to prevent duplicate processing
  final Set<String> _processingPurchases = {};

  // 👈 Update constructor to accept idem
  PlayBillingService({
    required WalletRepositoryImpl repo,
    required IdempotencyHelper idem, // 👈 Add this
  }) : _repo = repo,
       _idem = idem; // 👈 Initialize it

  Future<void> init() async {
    _isAvailable = await _iap.isAvailable();

    if (!_isAvailable) {
      debugPrint('⚠️ Google Play Billing not available');
      return;
    }

    // Enable pending purchases for Android
    //   if (defaultTargetPlatform == TargetPlatform.android) {
    //   final androidPlatform = _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    //   await androidPlatform.enablePendingPurchases();
    // }

    debugPrint('✅ Google Play Billing initialized');
  }

  void dispose() {
    _subscription?.cancel();
  }

  /// Main method to purchase coins
  Future<TransactionModel?> buyAndComplete({
    required String productId,
    String? packageCode,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (_isPurchasing) {
      debugPrint('⚠️ Purchase already in progress');
      throw Exception('Purchase already in progress');
    }

    if (!_isAvailable) {
      throw Exception('Google Play Billing not available');
    }

    _isPurchasing = true;
    _subscription?.cancel(); // Cancel any existing subscription

    final completer = Completer<TransactionModel?>();

    try {
      // 1. Query product details
      debugPrint('🔍 Querying product: $productId');
      final productResponse = await _iap.queryProductDetails({productId});

      if (productResponse.error != null) {
        throw Exception(
          'Failed to query product: ${productResponse.error!.message}',
        );
      }

      if (productResponse.productDetails.isEmpty) {
        throw Exception('Product not found: $productId');
      }

      final productDetails = productResponse.productDetails.first;
      debugPrint('✅ Product found: ${productDetails.title}');

      // 2. Generate idempotency key using helper
      final idempotencyKey = _idem.generateKey(); // 👈 Use helper
      await _idem.persist(idempotencyKey, {
        // 👈 Use helper
        'productId': productId,
        'packageCode': packageCode,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // 3. Set up purchase stream listener
      _subscription = _iap.purchaseStream.listen(
        (purchases) => _handlePurchaseUpdates(
          purchases,
          completer,
          productId,
          idempotencyKey,
          packageCode,
        ),
        onError: (error) {
          debugPrint('❌ Purchase stream error: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      // 4. Start purchase
      debugPrint('💰 Starting purchase for: $productId');
      final purchaseParam = PurchaseParam(productDetails: productDetails);
      final success = await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: false, // We'll acknowledge after server verification
      );

      if (!success) {
        throw Exception('Failed to start purchase');
      }

      // 5. Wait for completion with timeout
      final result = await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw Exception(
            'Purchase timed out after ${timeout.inSeconds} seconds',
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

      // Prevent duplicate processing
      final purchaseId = '${purchase.purchaseID}_${purchase.productID}';
      if (_processingPurchases.contains(purchaseId)) {
        debugPrint('⚠️ Already processing purchase: $purchaseId');
        continue;
      }
      _processingPurchases.add(purchaseId);

      debugPrint(
        '📦 Purchase update: ${purchase.status} for ${purchase.productID}',
      );

      // Handle different purchase states
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
                _processingPurchases.remove(purchaseId);
              })
              .catchError((error) {
                _processingPurchases.remove(purchaseId);
                if (!completer.isCompleted) {
                  completer.completeError(error);
                }
              });
          break;

        case PurchaseStatus.error:
          debugPrint('❌ Purchase error: ${purchase.error}');
          _processingPurchases.remove(purchaseId);
          if (!completer.isCompleted) {
            completer.completeError(purchase.error ?? 'Purchase failed');
          }
          _iap.completePurchase(purchase);
          break;

        case PurchaseStatus.pending:
          debugPrint('⏳ Purchase pending...');
          // Don't complete yet, wait for final status
          _processingPurchases.remove(purchaseId);
          break;

        case PurchaseStatus.canceled:
          debugPrint('🚫 Purchase canceled by user');
          _processingPurchases.remove(purchaseId);
          if (!completer.isCompleted) {
            completer.complete(null); // null indicates user canceled
          }
          _iap.completePurchase(purchase);
          break;
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchase,
    Completer<TransactionModel?> completer,
    String idempotencyKey,
    String? packageCode,
  ) async {
    try {
      if (purchase is! GooglePlayPurchaseDetails) {
        throw Exception('Only Google Play purchases are supported');
      }

      final purchaseToken = purchase.billingClientPurchase.purchaseToken;
      final productId = purchase.productID;

      debugPrint('✅ Purchase successful! Token: $purchaseToken');

      // Verify with backend
      debugPrint('🔐 Verifying purchase with server...');
      final transaction = await _repo.purchaseWithToken(
        productId: productId,
        purchaseToken: purchaseToken,
        packageCode: packageCode,
        idempotencyKey: idempotencyKey,
      );

      debugPrint('✅ Server verification successful!');

      // Mark idempotency as completed
      await _idem.complete(idempotencyKey); // 👈 Use helper

      // Complete/acknowledge the purchase with Google Play
      try {
        await _iap.completePurchase(purchase);
        debugPrint('✅ Purchase acknowledged with Google Play');
      } catch (e) {
        // Log but don't fail - server already credited
        debugPrint('⚠️ Warning: Failed to acknowledge purchase: $e');
      }

      // Clear pending purchase (from SharedPreferences)
      await _clearPendingPurchase(idempotencyKey);

      if (!completer.isCompleted) {
        completer.complete(transaction);
      }
    } catch (e) {
      debugPrint('❌ Server verification failed: $e');

      // DO NOT acknowledge the purchase if verification fails
      // This allows retry through the app

      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
  }

  // Keep these methods for backward compatibility, but they're less critical
  // now that we have IdempotencyHelper
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
      debugPrint('Failed to save pending purchase: $e');
    }
  }

  Future<void> _clearPendingPurchase(String idempotencyKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_purchases') ?? [];
      final filtered = pending.where((item) {
        try {
          final map = jsonDecode(item);
          return map['idempotency_key'] != idempotencyKey;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList('pending_purchases', filtered);
    } catch (e) {
      debugPrint('Failed to clear pending purchase: $e');
    }
  }

  Future<void> retryPendingPurchases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_purchases') ?? [];

      for (final item in pending) {
        try {
          final data = jsonDecode(item);
          // Attempt to verify again
          // This would need a method to check purchase status with Google
          // For now, just log
          debugPrint('Found pending purchase: $data');
        } catch (e) {
          debugPrint('Failed to parse pending purchase: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to retry pending purchases: $e');
    }
  }
}
