import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  final File? localFile;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const VideoThumbnailWidget({
    Key? key,
    required this.videoUrl,
    this.localFile,
    this.width = 200,
    this.height = 150,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
    this.errorBuilder,
  }) : super(key: key);

  @override
  _VideoThumbnailWidgetState createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  late Future<File?> _thumbnailFuture;
  final Map<String, File> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _generateThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.localFile != widget.localFile) {
      _thumbnailFuture = _generateThumbnail();
    }
  }

  Future<File?> _generateThumbnail() async {
    final cacheKey = widget.videoUrl;

    // Check cache first
    if (_thumbnailCache.containsKey(cacheKey)) {
      return _thumbnailCache[cacheKey];
    }

    try {
      // Check if thumbnail already exists in temp directory
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath =
          '${tempDir.path}/thumbnail_${cacheKey.hashCode}.jpg';
      final thumbnailFile = File(thumbnailPath);

      if (await thumbnailFile.exists()) {
        _thumbnailCache[cacheKey] = thumbnailFile;
        return thumbnailFile;
      }

      // Generate new thumbnail
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: widget.localFile?.path ?? widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth:
            widget.width.toInt() *
            2, // Generate at higher resolution for better quality
        quality: 85,
        timeMs: 1000,
      );

      if (thumbnailData != null) {
        await thumbnailFile.writeAsBytes(thumbnailData);
        _thumbnailCache[cacheKey] = thumbnailFile;
        return thumbnailFile;
      }
    } catch (e) {
      debugPrint('❌ Error generating video thumbnail: $e');
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingBuilder?.call(
                context,
                Container(
                  width: widget.width,
                  height: widget.height,
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary_,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                null,
              ) ??
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary_,
                    strokeWidth: 2,
                  ),
                ),
              );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder:
                widget.errorBuilder ??
                (context, error, stackTrace) {
                  return Container(
                    width: widget.width,
                    height: widget.height,
                    color: Colors.black,
                    child: Center(
                      child: Icon(
                        Icons.videocam,
                        color: Colors.white.withOpacity(0.8),
                        size: 32,
                      ),
                    ),
                  );
                },
          );
        }

        return widget.errorBuilder?.call(context, Error(), null) ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.black,
              child: Center(
                child: Icon(
                  Icons.videocam,
                  color: Colors.white.withOpacity(0.8),
                  size: 32,
                ),
              ),
            );
      },
    );
  }
}
