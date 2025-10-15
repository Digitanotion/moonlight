import 'package:dio/dio.dart';

/// Very small ETag cache: keeps last ETag per URL in-memory.
/// If the server returns 304 Not Modified, we reuse the last body kept by Dio.
/// (Dio doesn't cache body by default; this interceptor just adds If-None-Match)
class EtagCacheInterceptor extends Interceptor {
  final _etags = <String, String>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() == 'GET') {
      final tag = _etags[options.uri.toString()];
      if (tag != null && tag.isNotEmpty) {
        options.headers['If-None-Match'] = tag;
      }
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final etag = response.headers.value('etag');
    if (etag != null && etag.isNotEmpty) {
      _etags[response.requestOptions.uri.toString()] = etag;
    }
    super.onResponse(response, handler);
  }
}
