// lib/features/gifts/fx/gift_fx_service.dart
//
// Full-screen gift animations ("gift FX"), TikTok-style: a big transparent
// 3D video with sound over the live when an expensive gift is sent.
//
// Which gifts have one comes from the server's gift catalog: a gift's
// `meta.fx.url` is its animation (a "side-by-side alpha" MP4 — see
// android/.../GiftFxChannel.kt). Files are downloaded once and cached on
// the phone, so a gift plays instantly the next time.
//
// Anything that learns about a sent gift calls [GiftFx.instance.show];
// the GiftFxLayer on screen (live viewer / host) plays them in order.

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:path_provider/path_provider.dart';

/// One gift to animate.
class GiftFxEvent {
  final String giftCode;
  final String giftTitle;
  final String senderName;
  final String? senderAvatar;
  final String? recipientName; // null = the host
  final int quantity;
  final int coins;

  const GiftFxEvent({
    required this.giftCode,
    required this.giftTitle,
    required this.senderName,
    this.senderAvatar,
    this.recipientName,
    this.quantity = 1,
    this.coins = 0,
  });
}

/// A gift's animation as set on the server.
class GiftFxSpec {
  final String url;
  final int version;
  const GiftFxSpec(this.url, this.version);
}

class GiftFx {
  GiftFx._();
  static final GiftFx instance = GiftFx._();

  static const native = MethodChannel('com.app.moonlightstream/gift_fx');

  /// Transparent video playback is Android-only for now; iOS keeps the
  /// small gift card.
  bool get supported => !kIsWeb && Platform.isAndroid;

  final _events = StreamController<GiftFxEvent>.broadcast();
  Stream<GiftFxEvent> get events => _events.stream;

  /// Player events from native: (textureId, firstFrame|completed|error).
  final _playerEvents = StreamController<(int, String)>.broadcast();
  Stream<(int, String)> get playerEvents {
    _listenNative();
    return _playerEvents.stream;
  }

  bool _nativeHooked = false;
  void _listenNative() {
    if (_nativeHooked) return;
    _nativeHooked = true;
    native.setMethodCallHandler((call) async {
      if (call.method != 'event' || call.arguments is! Map) return;
      final m = call.arguments as Map;
      final id = (m['textureId'] as num?)?.toInt();
      if (id != null) _playerEvents.add((id, '${m['type']}'));
    });
  }

  Map<String, GiftFxSpec> _specs = {};
  Map<String, String> _titles = {};
  DateTime? _loadedAt;
  Future<void>? _loading;
  final Map<String, Future<String?>> _downloads = {};

  /// A sent gift. Shown full screen when the gift has an animation.
  void show(GiftFxEvent e) {
    if (!supported) return;
    _events.add(e);
  }

  /// Whether [code] has a full-screen animation (catalog must be loaded).
  bool hasFx(String code) => _specs.containsKey(code);

  String titleFor(String code) => _titles[code] ?? _prettify(code);

  /// Loads the catalog's animation links (at most every 10 minutes).
  Future<void> loadCatalog({bool force = false}) {
    if (!supported) return Future.value();
    final fresh =
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(minutes: 10);
    if (fresh && !force) return Future.value();
    return _loading ??= _fetchCatalog().whenComplete(() => _loading = null);
  }

  Future<void> _fetchCatalog() async {
    try {
      final res = await sl<DioClient>().dio.get('/api/v1/wallet/gifts');
      final list = (res.data is Map ? res.data['data'] : null) as List? ?? [];
      final specs = <String, GiftFxSpec>{};
      final titles = <String, String>{};
      for (final g in list) {
        if (g is! Map) continue;
        final code = '${g['code'] ?? ''}';
        if (code.isEmpty) continue;
        titles[code] = '${g['title'] ?? code}';
        final meta = g['meta'];
        final fx = meta is Map ? meta['fx'] : null;
        var url = fx is Map ? '${fx['url'] ?? ''}' : '';
        // "/gift-fx/…" = on the API's own domain.
        if (url.startsWith('/')) {
          url = Uri.parse(
            sl<DioClient>().dio.options.baseUrl,
          ).resolve(url).toString();
        }
        if (url.startsWith('http')) {
          specs[code] = GiftFxSpec(url, (fx['v'] as num?)?.toInt() ?? 1);
        }
      }
      _specs = specs;
      _titles = titles;
      _loadedAt = DateTime.now();
      debugPrint('🎁 [GiftFx] ${specs.length} gift animations: ${specs.keys}');
    } catch (e) {
      debugPrint('⚠️ [GiftFx] catalog load failed: $e');
    }
  }

  /// Downloads every animation not on the phone yet, one at a time (called
  /// when a live opens, so gifts play instantly) — on Wi-Fi only. All of
  /// them together are ~55 MB, too much for mobile data: there a gift's
  /// file is fetched the first time someone sends it (0.5–3 MB) and kept.
  Future<void> prefetchAll() async {
    if (!supported || _prefetching) return;
    _prefetching = true;
    try {
      await loadCatalog();
      for (final code in _specs.keys.toList()) {
        if (!await _onWifi()) return; // stop if they leave Wi-Fi
        await fileFor(code);
      }
    } finally {
      _prefetching = false;
    }
  }

  bool _prefetching = false;

  static Future<bool> _onWifi() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.contains(ConnectivityResult.wifi) ||
          r.contains(ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  /// Local file for [code]'s animation, downloading it if needed.
  /// Null when the gift has none or the download fails.
  Future<String?> fileFor(String code) async {
    await loadCatalog();
    final spec = _specs[code];
    if (spec == null) return null;
    final key = '${code}_v${spec.version}';
    return _downloads[key] ??= _download(key, spec).then((p) {
      if (p == null) _downloads.remove(key); // retry next time
      return p;
    });
  }

  Future<String?> _download(String key, GiftFxSpec spec) async {
    try {
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/gift_fx',
      );
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$key.mp4');
      if (await file.exists() && await file.length() > 1024) return file.path;
      final tmp = File('${file.path}.part');
      await Dio().download(
        spec.url,
        tmp.path,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
      await tmp.rename(file.path);
      // Old versions of this gift's animation.
      final prefix = key.substring(0, key.lastIndexOf('_v') + 2);
      await for (final f in dir.list()) {
        final name = f.uri.pathSegments.last;
        if (name.startsWith(prefix) && !name.startsWith(key)) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
      return file.path;
    } catch (e) {
      debugPrint('⚠️ [GiftFx] download ${spec.url} failed: $e');
      return null;
    }
  }

  static String _prettify(String code) => code
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
