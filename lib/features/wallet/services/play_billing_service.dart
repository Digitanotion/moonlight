// lib/features/wallet/services/play_billing_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:moonlight/features/wallet/data/datasources/wallet_remote_mapper.dart';
import 'package:moonlight/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:moonlight/features/wallet/domain/models/transaction_model.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';

import '../services/idempotency_helper.dart';

/// PlayBillingService: orchestrates Play Billing -> backend verification -> acknowledge.
/// - Exposes buyAndComplete(productId, ...)
/// - Returns TransactionModel on success (or null)
class PlayBillingService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final WalletRepositoryImpl repo;
  final IdempotencyHelper idem;
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<PurchaseDetails>>? _sub;

  PlayBillingService({required this.repo, required this.idem});

  /// Call once on app startup (optional)
  Future<void> init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('PlayBillingService: Play Billing NOT available');
    } else {
      debugPrint('PlayBillingService: Play Billing available');
    }
    // We don't permanently attach a subscription here; buyAndComplete installs a one-off listener.
  }

  void dispose() {
    _sub?.cancel();
  }

  /// End-to-end purchase:
  /// - productId: Play product id (SKU)
  /// - packageCode: optional server package code (if your server needs it)
  /// - isPurchaseAndGift/gift params omitted here; you can extend method if needed.
  Future<TransactionModel?> buyAndComplete({
    required String productId,
    String? packageCode,
    // Optional fields for purchase-and-gift variant (extend as needed)
    bool isPurchaseAndGift = false,
    String? giftCode,
    String? toUserUuid,
    String? livestreamId,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    // 1) Ensure Play Billing available
    final available = await _iap.isAvailable();
    if (!available) {
      throw Exception('Play Billing not available on this device');
    }

    // 2) Query product details
    final productResponse = await _iap.queryProductDetails({productId});
    if (productResponse.error != null) {
      throw Exception(
        'Failed to query product details: ${productResponse.error!.message}',
      );
    }
    if (productResponse.productDetails.isEmpty) {
      throw Exception('Product not found in Play Console: $productId');
    }
    final productDetails = productResponse.productDetails.first;

    // 3) Create idempotency key and persist metadata (so we can recover after crash)
    final idempotencyKey = _uuid.v4();
    await idem.persist(idempotencyKey, {
      'productId': productId,
      'packageCode': packageCode,
      'op': isPurchaseAndGift ? 'purchase_and_gift' : 'purchase',
      if (giftCode != null) 'giftCode': giftCode,
      if (toUserUuid != null) 'toUserUuid': toUserUuid,
      'created_at': DateTime.now().toIso8601String(),
    });

    // 4) PurchaseParam and start purchase (consumable)
    final purchaseParam = PurchaseParam(productDetails: productDetails);
    // autoConsume=false ensures we control acknowledgement/consumption
    final buyResult = await _iap.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: false,
    );

    // 5) Listen for the purchase update and wait for the purchase for this productId
    final completer = Completer<PurchaseDetails?>();
    StreamSubscription<List<PurchaseDetails>>? sub;
    sub = _iap.purchaseStream.listen(
      (purchases) {
        for (final p in purchases) {
          if (p.productID != productId) continue;
          // Found a matching purchase, complete the completer only once
          if (!completer.isCompleted) completer.complete(p);
          break;
        }
      },
      onError: (err) {
        if (!completer.isCompleted) completer.completeError(err);
      },
    );

    PurchaseDetails? purchaseDetails;
    try {
      purchaseDetails = await completer.future.timeout(
        timeout,
        onTimeout: () {
          sub?.cancel();
          throw Exception('Purchase timed out after ${timeout.inSeconds}s');
        },
      );
    } finally {
      // cancel listener when done
      sub?.cancel();
    }

    if (purchaseDetails == null) {
      throw Exception('Failed to obtain purchase details');
    }

    // 6) Handle purchase status
    if (purchaseDetails.status == PurchaseStatus.pending) {
      // Shouldn't happen because we awaited non-pending, but handle gracefully
      throw Exception('Purchase is pending – try again later');
    }

    if (purchaseDetails.status == PurchaseStatus.error) {
      final message =
          purchaseDetails.error?.message ?? 'Unknown purchase error';
      throw Exception('Purchase error: $message');
    }

    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      // 7) Get purchase token (serverVerificationData) and send to backend for verification
      final purchaseToken =
          purchaseDetails.verificationData.serverVerificationData;
      try {
        TransactionModel? txn;
        if (isPurchaseAndGift) {
          // If you plan to support purchase-and-gift, extend your repo to implement purchaseAndGift
          final res = await repo.purchaseAndGift(
            productId: productId,
            purchaseToken: purchaseToken,
            giftCode: giftCode!,
            toUserUuid: toUserUuid!,
            livestreamId: livestreamId,
            idempotencyKey: idempotencyKey,
          );
          // Map purchase txn from res if available
          final purchaseTxnJson =
              (res['transactions'] != null &&
                  res['transactions']['purchase'] != null)
              ? res['transactions']['purchase']
              : (res['purchase'] ?? res['transaction']);
          if (purchaseTxnJson != null) {
            txn = WalletRemoteMapper.transactionFromJson(
              Map<String, dynamic>.from(purchaseTxnJson),
            );
          }
        } else {
          // Regular purchase verify
          txn = await repo.purchaseWithToken(
            productId: productId,
            purchaseToken: purchaseToken,
            packageCode: packageCode,
            idempotencyKey: idempotencyKey,
          );
        }

        // 8) Backend verified: mark idempotency complete and acknowledge/complete the purchase
        await idem.complete(idempotencyKey);

        // Complete/acknowledge the purchase with the platform (Android)
        try {
          await _iap.completePurchase(purchaseDetails);
        } catch (ackError) {
          // Log but do not fail the overall operation if ack fails (app can recover)
          debugPrint('Warning: completePurchase failed: $ackError');
        }

        return txn;
      } catch (e) {
        // If the server verification fails, DO NOT acknowledge the purchase.
        // This leaves the purchase unacknowledged so it can be retried or reconciled.
        // Bubble up the error so UI can show message and retry.
        rethrow;
      }
    }

    // If we reach here, something unexpected happened
    throw Exception('Unhandled purchase status: ${purchaseDetails.status}');
  }
}
