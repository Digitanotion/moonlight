// lib/features/chat/presentation/utils/file_utils.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class FileUtils {
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100MB
  static const int maxImageDimension = 1920;
  static const int imageQuality = 85;

  static Future<File?> validateAndCompressImage(XFile imageFile) async {
    try {
      final file = File(imageFile.path);

      // Check if file exists
      if (!await file.exists()) {
        debugPrint('❌ Image file does not exist');
        return null;
      }

      // Read file bytes
      final bytes = await file.readAsBytes();

      // Check file size
      if (bytes.length > maxImageSize) {
        debugPrint('❌ Image too large: ${bytes.length} bytes');
        return null;
      }

      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('❌ Failed to decode image');
        return null;
      }

      // Resize if needed
      img.Image processedImage = image;
      if (image.width > maxImageDimension || image.height > maxImageDimension) {
        processedImage = img.copyResize(
          image,
          width: image.width > maxImageDimension ? maxImageDimension : null,
          height: image.height > maxImageDimension ? maxImageDimension : null,
        );
      }

      // Encode with quality
      final compressedBytes = img.encodeJpg(
        processedImage,
        quality: imageQuality,
      );

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(compressedBytes);

      debugPrint(
        '✅ Image compressed: ${bytes.length} -> ${compressedBytes.length} bytes',
      );
      return tempFile;
    } catch (e) {
      debugPrint('❌ Error compressing image: $e');
      return null;
    }
  }

  static Future<File?> validateVideo(XFile videoFile) async {
    try {
      final file = File(videoFile.path);

      if (!await file.exists()) {
        debugPrint('❌ Video file does not exist');
        return null;
      }

      final bytes = await file.length();

      if (bytes > maxVideoSize) {
        debugPrint('❌ Video too large: $bytes bytes');
        return null;
      }

      return file;
    } catch (e) {
      debugPrint('❌ Error validating video: $e');
      return null;
    }
  }
}
