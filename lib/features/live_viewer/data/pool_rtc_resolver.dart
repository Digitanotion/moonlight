// lib/features/live_viewer/data/pool_rtc_resolver.dart
//
// NEW FILE. Bridges AgoraEnginePool's abstract resolve() callback
// with your actual HTTP layer and LiveItem domain model.
//
// The pool itself has zero knowledge of LiveItem, DioClient, or your
// backend URL structure. This resolver is the ONLY place that knows
// how to turn "index N in the livestream list" into a StreamJoinRequest
// that the pool can act on.
//
// It also maintains an in-memory channel cache so that:
//   a) repeated resolve() calls for the same index don't hit the network
//      more than once (important during fast rotation loops)
//   b) _rotateTo()'s reuse detection can eventually be extended with a
//      synchronous channel-name lookup without any extra network cost
//
// USAGE: create one instance per pager session, pass its resolve()
// method as the `resolve` parameter to pool.setInitialWindow() and
// pool.rotate().

import 'package:flutter/foundation.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';

class PoolRtcResolver {
  PoolRtcResolver({required this.http});

  final DioClient http;

  // Cache: index → StreamJoinRequest. Cleared when the item list changes
  // (i.e. when the pager receives new items from outside).
  final Map<int, StreamJoinRequest> _cache = {};

  // Channel cache: index → channelId. Allows cheap synchronous lookup
  // by _rotateTo's reuse detection once we extend it.
  final Map<int, String> _channelCache = {};

  /// Returns the cached channel name for [index], or null if not yet
  /// resolved. Used by AgoraEnginePool._rotateTo() for reuse detection
  /// once we wire in the synchronous matching path.
  String? cachedChannelFor(int index) => _channelCache[index];

  void clearCache() {
    _cache.clear();
    _channelCache.clear();
  }

  /// The function passed directly to pool.setInitialWindow() and
  /// pool.rotate() as the `resolve` parameter.
  ///
  /// Returns null when:
  ///   - [index] is out of bounds for [items]
  ///   - the backend RTC fetch fails (pool treats null → unavailable)
  Future<StreamJoinRequest?> resolve(List<LiveItem> items, int index) async {
    if (index < 0 || index >= items.length) return null;

    // Return cached entry immediately — no network call needed.
    if (_cache.containsKey(index)) return _cache[index];

    final item = items[index];

    try {
      final res = await http.dio.get(
        '/api/v1/live/${item.uuid}/rtc',
        queryParameters: {'role': 'audience'},
      );

      final data = _asMap(res.data);

      final req = StreamJoinRequest(
        livestreamParam: item.uuid,
        appId: (data['app_id'] ?? '').toString(),
        channel: (data['channel'] ?? item.channel).toString(),
        rtcUid: (data['rtc_uid'] ?? '0').toString(),
        rtcToken: (data['rtc_token'] ?? '').toString(),
      );

      _cache[index] = req;
      _channelCache[index] = req.channel;

      debugPrint(
        '🔑 [Resolver] Resolved index $index → '
        'ch=${req.channel} uid=${req.rtcUid}',
      );

      return req;
    } catch (e) {
      debugPrint('⚠️ [Resolver] RTC fetch failed for index $index: $e');
      return null;
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}