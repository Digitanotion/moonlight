// exceptions.dart
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null
      ? 'ServerException: $message (Status: $statusCode)'
      : 'ServerException: $message';
}

class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
