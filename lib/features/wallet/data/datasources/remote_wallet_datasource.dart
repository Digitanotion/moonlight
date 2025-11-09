// lib/features/wallet/data/datasources/remote_wallet_datasource.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../domain/models/coin_package.dart';
import '../../domain/models/transaction_model.dart';
import 'wallet_remote_mapper.dart';

class RemoteWalletDataSource {
  final Dio client;
  RemoteWalletDataSource({required this.client});

  Future<Map<String, dynamic>> _extractData(Response res) async {
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    if (res.data is String)
      return Map<String, dynamic>.from(jsonDecode(res.data as String));
    throw Exception('Unexpected response type');
  }

  Future<int> fetchBalance() async {
    final res = await client.get('/api/v1/wallet');
    final data = await _extractData(res);
    final payload = data['data'] as Map<String, dynamic>;
    return payload['balance'] as int;
  }

  Future<double> fetchEarned() async {
    final res = await client.get('/api/v1/wallet');
    final data = await _extractData(res);
    final payload = data['data'] as Map<String, dynamic>;
    final earnedcents =
        payload['earnings_cents'] * 0.01 / 1; //Convert to Dollar
    final bonusCentsEarned =
        payload['bonus_cents'] * 0.01 / 1; //Convert to Dollar
    final earnedDollar = earnedcents + bonusCentsEarned;
    return earnedDollar;
  }

  Future<List<CoinPackage>> fetchPackages() async {
    final res = await client.get('/api/v1/wallet/packages');
    final data = await _extractData(res);
    final list = (data['data'] as List<dynamic>?) ?? [];
    return list
        .map(
          (e) => WalletRemoteMapper.packageFromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<TransactionModel>> fetchRecentActivity({
    int page = 1,
    int perPage = 25,
  }) async {
    final res = await client.get(
      '/api/v1/wallet/transactions',
      queryParameters: {'per_page': perPage, 'page': page},
    );
    final data = await _extractData(res);
    final payload = data['data'];
    final items = payload is Map && payload['data'] is List
        ? payload['data'] as List
        : (data['data'] as List? ?? []);
    final list = (items)
        .map(
          (e) => WalletRemoteMapper.transactionFromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    // print(List.from(list));
    return List<TransactionModel>.from(list);
  }

  Future<TransactionModel> fetchTransaction(String transactionId) async {
    final res = await client.get('/api/v1/wallet/transactions/$transactionId');
    final data = await _extractData(res);
    return WalletRemoteMapper.transactionFromJson(
      Map<String, dynamic>.from(data['data'] as Map),
    );
  }

  Future<TransactionModel> purchase({
    required String productId,
    required String purchaseToken,
    String? packageCode,
    required String idempotencyKey,
  }) async {
    final body = {
      'product_id': productId,
      'purchase_token': purchaseToken,
      if (packageCode != null) 'package_code': packageCode,
      'idempotency_key': idempotencyKey,
    };
    final res = await client.post('/api/v1/wallet/purchase', data: body);
    final data = await _extractData(res);
    return WalletRemoteMapper.transactionFromJson(
      Map<String, dynamic>.from(data['data'] as Map),
    );
  }

  Future<Map<String, dynamic>> purchaseAndGift({
    required String productId,
    required String purchaseToken,
    required String giftCode,
    required String toUserUuid,
    String? livestreamId,
    required String idempotencyKey,
  }) async {
    final body = {
      'product_id': productId,
      'purchase_token': purchaseToken,
      'gift_code': giftCode,
      'to_user_uuid': toUserUuid,
      if (livestreamId != null) 'livestream_id': livestreamId,
      'idempotency_key': idempotencyKey,
    };
    final res = await client.post(
      '/api/v1/wallet/purchase-and-gift',
      data: body,
    );
    final data = await _extractData(res);
    return Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<Map<String, dynamic>> gift({
    required String giftCode,
    required String toUserUuid,
    String? livestreamId,
    String? pin,
    required String idempotencyKey,
  }) async {
    final body = {
      'gift_code': giftCode,
      'to_user_uuid': toUserUuid,
      if (livestreamId != null) 'livestream_id': livestreamId,
      if (pin != null) 'pin': pin,
      'idempotency_key': idempotencyKey,
    };
    final res = await client.post('/api/v1/wallet/gift', data: body);
    final data = await _extractData(res);
    return Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<Map<String, dynamic>> createTransferRequest({
    required String toUserUuid,
    required int coins,
    String? reason,
    required String pin,
    required String idempotencyKey,
  }) async {
    final body = {
      'to_user_uuid': toUserUuid,
      'coins': coins,
      if (reason != null) 'reason': reason,
      'pin': pin,
      'idempotency_key': idempotencyKey,
    };
    final res = await client.post(
      '/api/v1/wallet/transfer-request',
      data: body,
    );
    final data = await _extractData(res);
    return Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<Map<String, dynamic>> createWithdrawRequest({
    required int amountUsdCents,
    required String bankAccountName,
    required String bankAccountNumber,
    required String bankName,
    required String country,
    String? swift,
    String? email,
    String? phone,
    String? reason,
    required String pin,
    required String idempotencyKey,
  }) async {
    final body = {
      'amount_usd_cents': amountUsdCents,
      'bank_account_name': bankAccountName,
      'bank_account_number': bankAccountNumber,
      'bank_name': bankName,
      'country': country,
      if (swift != null) 'swift': swift,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (reason != null) 'reason': reason,
      'pin': pin,
      'idempotency_key': idempotencyKey,
    };
    final res = await client.post(
      '/api/v1/wallet/withdraw-request',
      data: body,
    );
    final data = await _extractData(res);
    return Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<void> setPin(String pin) async {
    await client.post('/api/v1/wallet/pin/set', data: {'pin': pin});
  }

  Future<bool> verifyPin(String pin) async {
    final res = await client.post(
      '/api/v1/wallet/pin/verify',
      data: {'pin': pin},
    );
    final data = await _extractData(res);
    return (data['status'] as String?) == 'success';
  }
}
