// lib/features/chat/presentation/utils/save_chat_media.dart
//
// "Save to phone" for chat photos and videos: downloads the file (or uses
// the local copy we just sent) and puts it in the device gallery.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/widgets/top_snack.dart';
import 'package:path_provider/path_provider.dart';

Future<void> saveChatMedia(
  BuildContext context,
  MediaAttachment media, {
  File? localFile,
}) async {
  final isVideo = media.isVideo;
  TopSnack.info(context, isVideo ? 'Saving video…' : 'Saving photo…');
  try {
    if (!await Gal.hasAccess(toAlbum: true) &&
        !await Gal.requestAccess(toAlbum: true)) {
      if (context.mounted) {
        TopSnack.error(context, 'Allow photo access to save to your phone.');
      }
      return;
    }

    var path = localFile?.path;
    if (path == null || !File(path).existsSync()) {
      final dir = await getTemporaryDirectory();
      final ext = _extension(media);
      path =
          '${dir.path}/moonlight_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Dio().download(media.url, path);
    }

    if (isVideo) {
      await Gal.putVideo(path, album: 'Moonlight');
    } else {
      await Gal.putImage(path, album: 'Moonlight');
    }
    if (context.mounted) {
      TopSnack.success(
        context,
        isVideo ? 'Video saved to your gallery' : 'Photo saved to your gallery',
      );
    }
  } catch (e) {
    debugPrint('saveChatMedia failed: $e');
    if (context.mounted) {
      TopSnack.error(context, 'Couldn\'t save. Please try again.');
    }
  }
}

String _extension(MediaAttachment media) {
  final fromUrl = Uri.tryParse(media.url)?.pathSegments.lastOrNull ?? '';
  final dot = fromUrl.lastIndexOf('.');
  if (dot > 0 && fromUrl.length - dot <= 5) return fromUrl.substring(dot + 1);
  final sub = media.mimeType.split('/').last;
  if (sub == 'jpeg') return 'jpg';
  if (sub == 'quicktime') return 'mov';
  return sub.isEmpty ? (media.isVideo ? 'mp4' : 'jpg') : sub;
}
