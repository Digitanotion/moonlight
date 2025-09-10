// lib/core/config/runtime_config.dart
import 'package:dio/dio.dart';

class RuntimeConfig {
  final String agoraAppId;
  final String apiBaseUrl;
  const RuntimeConfig({required this.agoraAppId, required this.apiBaseUrl});
}

abstract class ConfigService {
  Future<RuntimeConfig> load();
}

class ConfigServiceHttp implements ConfigService {
  final Dio dio;
  ConfigServiceHttp(this.dio);

  @override
  Future<RuntimeConfig> load() async {
    final res = await dio.get('/api/v1/config/agora');
    return RuntimeConfig(
      agoraAppId: res.data['agora_app_id'] as String,
      apiBaseUrl: res.data['api_base_url'] as String,
    );
  }
}
