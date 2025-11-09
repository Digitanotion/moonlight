// lib/core/network/interceptors/idempotency_interceptor.dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class IdempotencyInterceptor extends Interceptor {
  final Uuid _uuid = const Uuid();
  final SharedPreferences _prefs;

  // endpoints that require idempotency behaviour (money-affecting)
  static final _moneyPaths = <String>{
    '/api/v1/wallet/purchase',
    '/api/v1/wallet/purchase-and-gift',
    '/api/v1/wallet/gift',
    '/api/v1/wallet/withdraw-request',
    '/api/v1/wallet/transfer-request',
    '/api/v1/wallet/topup',
  };

  IdempotencyInterceptor(this._prefs);

  bool _isMoneyEndpoint(RequestOptions options) {
    final path = options.path;
    return _moneyPaths.any((p) => path.contains(p));
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Normalize method
    final method = (options.method ?? 'GET').toUpperCase();

    // Only consider idempotency for mutating methods.
    const writeMethods = <String>{'POST', 'PUT', 'PATCH', 'DELETE'};

    // If this is a read request (GET/HEAD/etc), ensure we REMOVE any idempotency header
    // (defensive: prevents client from accidentally sending Idempotency-Key on GETs).
    if (!writeMethods.contains(method)) {
      if (options.headers.containsKey('Idempotency-Key')) {
        options.headers.remove('Idempotency-Key');
      }
      handler.next(options);
      return;
    }

    // From here on: mutating methods only.

    // If header already provided (maybe caller set it), keep it.
    final existingHeader = options.headers['Idempotency-Key'] as String?;
    if (existingHeader != null && existingHeader.isNotEmpty) {
      handler.next(options);
      return;
    }

    // If body contains idempotency_key, prefer that.
    String? bodyKey;
    try {
      if (options.data is Map) {
        bodyKey = (options.data as Map)['idempotency_key'] as String?;
      }
      // If you use FormData or other types, you can add more detection here if needed.
    } catch (_) {
      bodyKey = null;
    }

    if (bodyKey != null && bodyKey.isNotEmpty) {
      options.headers['Idempotency-Key'] = bodyKey;
      handler.next(options);
      return;
    }

    // Only auto-generate keys for real money endpoints (your whitelist).
    if (_isMoneyEndpoint(options)) {
      final generated = _uuid.v4();
      options.headers['Idempotency-Key'] = generated;
      // store a small signature locally (optional)
      try {
        final sig =
            '${options.method}-${options.path}-${DateTime.now().millisecondsSinceEpoch}';
        _prefs.setString('idem_$generated', sig);
      } catch (_) {
        // ignore prefs write errors
      }
    }

    handler.next(options);
  }
}
