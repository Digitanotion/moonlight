import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:flutter_svg/flutter_svg.dart';

class GiftVisuals {
  static const String _base = 'assets/gifts/';
  static Set<String>? _assets; // cache

  static Future<void> _ensureManifestLoaded() async {
    if (_assets != null) return;
    // Flutter 3.16+ dropped AssetManifest.json for AssetManifest.bin.
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _assets = manifest
          .listAssets()
          .where((k) => k.startsWith(_base) && k.endsWith('.svg'))
          .toSet();
      return;
    } catch (_) {/* fall through to legacy + probe */}
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = jsonDecode(manifestJson);
      _assets = manifest.keys
          .where((k) => k.startsWith(_base) && k.endsWith('.svg'))
          .toSet();
    } catch (_) {
      _assets = <String>{};
    }
  }

  /// Direct probe — used when the manifest lookup came up empty but the
  /// caller has a concrete code (avoids showing a blank fallback when the
  /// asset actually ships).
  static Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static final Map<String, IconData> _material = <String, IconData>{
    'ice_cream': Icons.icecream,
    'pizza': Icons.local_pizza,
    'wine': Icons.wine_bar,
    'rose': Icons.local_florist,
    'diamond': Icons.diamond,
    'moon': Icons.dark_mode,
  };

  static final Map<String, String> _emoji = <String, String>{
    'apple': '🍎',
    'strawberry': '🍓',
    'blueberry': '🫐',
    'grape': '🍇',
    'lemon': '🍋',
    'kiwi': '🥝',
    'honeydew': '🍈',
    'pear': '🍐',
    'quince': '🍐',
    'milk': '🥛',
    'chocolate': '🍫',
    'biscuit': '🍪',
    'shawarma': '🌯',
    'rainbow': '🌈',
    'gold': '🪙',
    'gold_ring': '💍',
    'jewelry': '💎',
    'perfume': '💄',
    'panda': '🐼',
    'eagle': '🦅',
    'peacock': '🦚',
    'pants': '👖',
    'handbag': '👜',
    'love': '💖',
    'moon': '🌙',
  };

  static Future<Widget> build(
    String code, {
    double size = 40,
    String? title,
    String? imageUrl,
    Color? color,
    TextStyle? emojiStyle,
  }) async {
    await _ensureManifestLoaded();
    final svgPath = '$_base$code.svg';
    final hasSvg = _assets!.contains(svgPath) ||
        (code.isNotEmpty && await _assetExists(svgPath));

    // ── Original priority (restored): emoji → bundled SVG → material →
    //    remote URL → fallback. Only the asset-manifest LOOKUP changed
    //    (AssetManifest.bin) so the bundled SVGs are actually found.

    // Emoji first: if this code maps to a defined emoji, show the emoji.
    if (_emoji.containsKey(code)) {
      return Text(
        _emoji[code]!,
        style: emojiStyle ?? TextStyle(fontSize: size * 0.9),
        semanticsLabel: title ?? code,
      );
    }

    // Bundled per-gift SVG artwork.
    if (hasSvg) {
      return SvgPicture.asset(
        svgPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color, BlendMode.srcIn),
        placeholderBuilder: (_) => Icon(
          Icons.card_giftcard,
          size: size * 0.7,
          color: color ?? Colors.white,
        ),
        semanticsLabel: title ?? code,
      );
    }

    // Material icons fallback (if code matches a material mapping)
    if (_material.containsKey(code)) {
      return Icon(_material[code], size: size, color: color ?? Colors.white);
    }

    // Remote image URL from the DB.
    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      final w = _remoteImage(imageUrl, size, code, title, color);
      if (w != null) return w;
    }

    // final fallback icon
    return Icon(Icons.card_giftcard, size: size, color: color ?? Colors.white);
  }

  static Widget? _remoteImage(
    String imageUrl,
    double size,
    String code,
    String? title,
    Color? color,
  ) {
    final isSvg = imageUrl.toLowerCase().endsWith('.svg');
    if (isSvg) {
      try {
        return SvgPicture.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SizedBox(
                width: size * 0.35,
                height: size * 0.35,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          semanticsLabel: title ?? code,
        );
      } catch (_) {}
    }
    return Image.network(
      imageUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.card_giftcard, size: size, color: color ?? Colors.white),
    );
  }
}
