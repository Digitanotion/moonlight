import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class RuntimeConfig {
  final String agoraAppId;
  final String apiBaseUrl; // e.g. https://svc.moonlightstream.app
  final String pusherKey;
  final String pusherCluster;

  const RuntimeConfig({
    required this.agoraAppId,
    required this.apiBaseUrl,
    required this.pusherKey,
    required this.pusherCluster,
  });
}

abstract class ConfigService {
  Future<RuntimeConfig> load();
}

/// Fetches /api/config
///
class ConfigServiceHttp implements ConfigService {
  final Dio dio;
  ConfigServiceHttp(this.dio);

  @override
  Future<RuntimeConfig> load() async {
    try {
      debugPrint('🚀 Loading runtime config...');
      debugPrint('   - Base URL: ${dio.options.baseUrl}');
      debugPrint('   - Full URL: ${dio.options.baseUrl}/v1/config');
      debugPrint('   - Headers: ${dio.options.headers}');

      final res = await dio.get('/v1/config');
      debugPrint('✅ Config API response status: ${res.statusCode}');
      debugPrint('📦 Config API response data: ${res.data}');
      debugPrint('📦 Response data type: ${res.data.runtimeType}');

      // Handle different response formats
      Map<String, dynamic> data;
      if (res.data is Map) {
        data = Map<String, dynamic>.from(res.data as Map);
      } else if (res.data is String) {
        // Try to parse as JSON string
        data = Map<String, dynamic>.from(jsonDecode(res.data as String));
      } else {
        throw Exception('Unexpected response type: ${res.data.runtimeType}');
      }

      // Debug each field with null safety
      debugPrint('🔍 Parsed config fields:');
      debugPrint('   - agora_app_id: ${data['agora_app_id']}');
      debugPrint('   - api_base_url: ${data['api_base_url']}');
      debugPrint('   - pusher_key: ${data['pusher_key']}');
      debugPrint('   - pusher_cluster: ${data['pusher_cluster']}');

      // Validate required fields
      if (data['pusher_key'] == null || data['pusher_key'].toString().isEmpty) {
        throw Exception('Pusher key is missing or empty in API response');
      }

      final config = RuntimeConfig(
        agoraAppId: data['agora_app_id']?.toString() ?? '',
        apiBaseUrl: (data['api_base_url']?.toString() ?? '').replaceAll(
          RegExp(r'/+$'),
          '',
        ),
        pusherKey: data['pusher_key']?.toString() ?? '',
        pusherCluster: data['pusher_cluster']?.toString() ?? 'mt1',
      );

      debugPrint('🎯 Final RuntimeConfig:');
      debugPrint('   - agoraAppId: ${config.agoraAppId}');
      debugPrint('   - apiBaseUrl: ${config.apiBaseUrl}');
      debugPrint(
        '   - pusherKey: ${config.pusherKey} (length: ${config.pusherKey.length})',
      );
      debugPrint('   - pusherCluster: ${config.pusherCluster}');

      return config;
    } catch (e) {
      debugPrint('❌ Failed to load runtime config: $e');
      if (e is DioException) {
        debugPrint('   - Dio error type: ${e.type}');
        debugPrint('   - Dio error message: ${e.message}');
        debugPrint('   - Response status: ${e.response?.statusCode}');
        debugPrint('   - Response data: ${e.response?.data}');
        debugPrint('   - Request URL: ${e.requestOptions.uri}');
        debugPrint('   - Request headers: ${e.requestOptions.headers}');
      }
      rethrow;
    }
  }
}
// class ConfigServiceHttp implements ConfigService {
//   final Dio dio;
//   ConfigServiceHttp(this.dio);

//   @override
//   Future<RuntimeConfig> load() async {
//     final res = await dio.get('/v1/config'); // -> /api/config due to baseUrl
//     final data = Map<String, dynamic>.from(res.data as Map);

//     return RuntimeConfig(
//       agoraAppId: data['agora_app_id'] as String,
//       apiBaseUrl: (data['api_base_url'] as String).replaceAll(
//         RegExp(r'/+$'),
//         '',
//       ),
//       pusherKey: data['pusher_key'] as String,
//       pusherCluster: data['pusher_cluster'] as String,
//     );
//   }
// }
