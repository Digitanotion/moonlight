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
///   https://moonlightstream.app/live/<uuid>   (verified App Link)
///   moonlight://live/<uuid>                    (custom scheme fallback)
///   https://moonlightstream.app/post/<id>
///   moonlight://post/<id>
///
/// Flutter's own deep-link routing is disabled (see
/// `flutter_deeplinking_enabled=false` in AndroidManifest + the
/// `onGenerateInitialRoutes` guard in main.dart) so this service is the
/// single entry point. It waits for the app to finish booting (splash →
/// first real route) before acting, then resolves a `/live` link against
/// the status endpoint and opens the viewer exactly like a Live-grid tap.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// Completed by the splash screen once it has navigated to the first real
  /// route. Deep links queue behind this so we never push a viewer on top of
  /// a still-initialising app (which left the RTC pool half-wired → the
  /// "spinner spins forever" symptom).
  final Completer<void> _appReady = Completer<void>();
  void markAppReady() {
    if (!_appReady.isCompleted) _appReady.complete();
  }

  // Cold start can deliver the same URI twice (getInitialLink + the stream).
  Uri? _lastHandled;
  DateTime _lastHandledAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    if (_started) return;
    _started = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (e) {
      debugPrint('DeepLinkService.getInitialLink: $e');
    }

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
    // De-dupe a cold-start URI arriving on both channels within a few seconds.
    final now = DateTime.now();
    if (uri == _lastHandled &&
        now.difference(_lastHandledAt) < const Duration(seconds: 4)) {
      return;
    }
    _lastHandled = uri;
    _lastHandledAt = now;

    debugPrint('🔗 Deep link: $uri');

    final isWeb = uri.scheme == 'https' || uri.scheme == 'http';
    final parts = <String>[
      if (!isWeb) uri.host,
      ...uri.pathSegments,
    ].where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return;

    final kind = parts[0];
    final value = parts[1];
    if (kind != 'live' && kind != 'post') return;

    // Wait for the app to finish booting (bounded, so a stuck splash can't
    // strand the link forever).
    try {
      await _appReady.future.timeout(const Duration(seconds: 12));
    } catch (_) {}

    switch (kind) {
      case 'live':
        await _openLive(value);
        break;
      case 'post':
        _push(RouteNames.postView, {'postId': value});
        break;
    }
  }

  Future<void> _openLive(String ref) async {
    if (ref.isEmpty) return;

    Map<String, dynamic> data;
    try {
      final res = await sl<DioClient>().dio.get('/api/v1/live/$ref/status');
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
      uuid: (data['uuid'] ?? ref).toString(),
      channel: channel,
      // /status doesn't return a stream cover — only the host's avatar. Put
      // it in hostAvatarUrl (not coverUrl) so the card's initials fallback
      // still kicks in correctly for hosts with no avatar either.
      coverUrl: null,
      hostAvatarUrl: (host['avatar_url'] ?? host['avatar'])?.toString(),
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

    final nav = MyApp.navigatorKey.currentState;
    if (nav == null) {
      // App-ready fired but the navigator isn't attached yet — retry briefly.
      Future.delayed(const Duration(milliseconds: 400), () => _openLive(ref));
      return;
    }
    nav.push(LiveViewerPager.route(items: [item], initialIndex: 0));
  }

  void _push(String route, Map<String, dynamic> args) {
    final nav = MyApp.navigatorKey.currentState;
    if (nav == null) {
      Future.delayed(
        const Duration(milliseconds: 400),
        () => _push(route, args),
      );
      return;
    }
    nav.pushNamed(route, arguments: args);
  }

  void _toast(String msg) {
    final ctx = MyApp.navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(content: Text(msg)));
  }
}
