// lib/core/network/interceptors/dio_extra_hook.dart
import 'package:dio/dio.dart';

class DioExtraHook extends Interceptor {
  final Dio dioInstance;
  DioExtraHook(this.dioInstance);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['dio'] = dioInstance;
    handler.next(options);
  }
}
