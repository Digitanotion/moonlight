import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

class GiftVisuals {
  static const String _base = 'assets/gifts/';
  static Set<String>? _assets; // cache

  static Future<void> _ensureManifestLoaded() async {
    if (_assets != null) return;
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
    final hasSvg = _assets!.contains(svgPath);

    // If we have a bundled SVG asset for this code, use SvgPicture.asset
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

    // Material icons fallback
    if (_material.containsKey(code)) {
      return Icon(_material[code], size: size, color: color ?? Colors.white);
    }

    // Emoji fallback
    if (_emoji.containsKey(code)) {
      return Text(
        _emoji[code]!,
        style: emojiStyle ?? TextStyle(fontSize: size * 0.9),
        semanticsLabel: title ?? code,
      );
    }

    // If we were given a remote image URL (raster or svg), show Image.network or SvgPicture.network
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // detect svg by extension (best-effort)
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            semanticsLabel: title ?? code,
          );
        } catch (_) {
          // fallthrough to raster attempt
        }
      }

      return Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return Icon(
            Icons.card_giftcard,
            size: size,
            color: color ?? Colors.white,
          );
        },
      );
    }

    // final fallback icon
    return Icon(Icons.card_giftcard, size: size, color: color ?? Colors.white);
  }
}
