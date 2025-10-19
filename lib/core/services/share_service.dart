// lib/core/services/share_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';

class ShareService {
  static Future<void> sharePost(Post post) async {
    final text = _buildShareText(post);
    final url = post.mediaUrl;

    if (url.isEmpty) {
      await Share.share(text);
      return;
    }

    try {
      final file = await _downloadToCache(url);
      if (file != null && await file.exists()) {
        await Share.shareXFiles([XFile(file.path)], text: text);
      } else {
        await Share.share(text);
      }
    } catch (e) {
      debugPrint('ShareService error: $e');
      await Share.share(text);
    }
  }

  static String _buildShareText(Post p) {
    final caption = p.caption.trim();
    final excerpt = caption.length <= 140
        ? caption
        : '${caption.substring(0, 140)}…';
    // Deep link the app should handle: moonlight://post/<id>
    final deepLink = 'moonlight://post/${p.id}';
    return [if (excerpt.isNotEmpty) excerpt, deepLink].join('\n\n');
  }

  static Future<File?> _downloadToCache(String url) async {
    final dio = GetIt.I<DioClient>().dio;
    final dir = await getTemporaryDirectory();
    final filename = url.split('/').last.split('?').first;
    final out = File('${dir.path}/$filename');
    final res = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes, followRedirects: true),
    );
    await out.writeAsBytes(res.data ?? const []);
    return out;
  }
}
