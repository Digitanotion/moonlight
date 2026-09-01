import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/live_viewer_pager.dart';
import 'package:moonlight/main.dart' show MyApp;

/// Handles inbound links:
///
///   https://moonlightstream.app/live/<uuid>   (verified App/Universal Link)
///   moonlight://live/<uuid>                    (custom scheme fallback)
///   https://moonlightstream.app/post/<id>
///   moonlight://post/<id>
///
/// A `/live` link is resolved against the stream-status endpoint (uuid is
/// accepted by the route binding) so we can hand the viewer route the id +
/// channel it needs, and so an ended/invalid stream degrades gracefully.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  Future<void> init() async {
    if (_started) return;
    _started = true;

    // Cold start.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        // Let the splash finish navigating to its first real route first.
        Future.delayed(const Duration(milliseconds: 1200), () => _handle(initial));
      }
    } catch (e) {
      debugPrint('DeepLinkService.getInitialLink: $e');
    }

    // Warm / running.
    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (e) => debugPrint('DeepLinkService stream: $e'),
    );
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> _handle(Uri uri) async {
    debugPrint('🔗 Deep link: $uri');

    // https://moonlightstream.app/live/<uuid>  → pathSegments = [live, <uuid>]
    // moonlight://live/<uuid>                  → host = live, path = [<uuid>]
    final isWeb = uri.scheme == 'https' || uri.scheme == 'http';
    final parts = <String>[
      if (!isWeb) uri.host,
      ...uri.pathSegments,
    ].where((s) => s.isNotEmpty).toList();

    if (parts.length < 2) return;
    final kind = parts[0];
    final value = parts[1];
    if (kind != 'live' && kind != 'post') return;

    switch (kind) {
      case 'live':
        await _openLive(value);
        break;
      case 'post':
        _push(RouteNames.postView, {'postId': value});
        break;
    }
  }

  Future<void> _openLive(String uuid) async {
    if (uuid.isEmpty) return;

    Map<String, dynamic> data;
    try {
      final res = await sl<DioClient>().dio.get('/api/v1/live/$uuid/status');
      data = (res.data is Map)
          ? (res.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};
    } catch (e) {
      debugPrint('DeepLinkService._openLive status: $e');
      _toast('Could not open that stream. Please try again.');
      return;
    }

    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status != 'online') {
      _toast(
        (data['message'] as String?) ?? 'That stream is not live right now.',
      );
      return;
    }

    final host = (data['host'] is Map)
        ? (data['host'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final id = (data['livestream_id'] as num?)?.toInt();
    final channel = data['channel'] as String?;
    if (id == null || channel == null || channel.isEmpty) {
      _toast('Could not open that stream.');
      return;
    }

    final slug = (host['user_slug'] ?? host['slug'] ?? '').toString();
    final item = LiveItem(
      id: id,
      uuid: (data['uuid'] ?? uuid).toString(),
      channel: channel,
      coverUrl: (host['avatar_url'] ?? host['avatar'])?.toString(),
      handle: slug.isNotEmpty ? '@$slug' : '@host',
      role: 'Host',
      countryIso2: null,
      countryName: null,
      viewers: (data['viewers'] as num?)?.toInt() ?? 0,
      title: data['title']?.toString(),
      startedAt: data['started_at']?.toString(),
      hostUuid: host['uuid']?.toString(),
      isPremium: (data['is_premium'] == true) ? 1 : 0,
      premiumFee: (data['entry_fee_coins'] as num?)?.toInt() ?? 0,
    );

    // Open exactly like a tap from the Live grid.
    void go() {
      final nav = MyApp.navigatorKey.currentState;
      if (nav == null) {
        Future.delayed(const Duration(milliseconds: 500), go);
        return;
      }
      nav.push(LiveViewerPager.route(items: [item], initialIndex: 0));
    }

    go();
  }

  void _push(String route, Map<String, dynamic> args) {
    void go() {
      final nav = MyApp.navigatorKey.currentState;
      if (nav == null) {
        Future.delayed(const Duration(milliseconds: 500), go);
        return;
      }
      nav.pushNamed(route, arguments: args);
    }

    go();
  }

  void _toast(String msg) {
    final ctx = MyApp.navigatorKey.currentContext;
    if (ctx == null) return;
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    messenger?.showSnackBar(SnackBar(content: Text(msg)));
  }
}
