import 'package:dio/dio.dart';

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
class ConfigServiceHttp implements ConfigService {
  final Dio dio;
  ConfigServiceHttp(this.dio);

  @override
  Future<RuntimeConfig> load() async {
    final res = await dio.get('/v1/config'); // -> /api/config due to baseUrl
    final data = Map<String, dynamic>.from(res.data as Map);

    return RuntimeConfig(
      agoraAppId: data['agora_app_id'] as String,
      apiBaseUrl: (data['api_base_url'] as String).replaceAll(
        RegExp(r'/+$'),
        '',
      ),
      pusherKey: data['pusher_key'] as String,
      pusherCluster: data['pusher_cluster'] as String,
    );
  }
}
