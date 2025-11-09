// lib/core/network/interceptors/auth_interceptor.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:mutex/mutex.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/auth/data/datasources/auth_remote_datasource.dart';

class AuthInterceptor extends Interceptor {
  final AuthLocalDataSource _local;
  final AuthRemoteDataSource _remote;
  final Mutex _refreshMutex = Mutex();

  AuthInterceptor(this._local, this._remote);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _local.readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    handler.next(options);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    final resp = err.response;
    if (resp?.statusCode == 401 &&
        !err.requestOptions.extra.containsKey('retried')) {
      await _refreshMutex.protect(() async {
        try {
          await _remote
              .refreshToken(); // expects remote to refresh and persist token via local datasource
        } catch (_) {}
      });

      final newToken = await _local.readToken();
      if (newToken != null && newToken.isNotEmpty) {
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        opts.extra['retried'] = true;
        try {
          final response = await err.requestOptions.extra['dio'].fetch(opts);
          return handler.resolve(response);
        } on DioError catch (e) {
          return handler.next(e);
        }
      }
    }
    handler.next(err);
  }
}
