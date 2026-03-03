// lib/features/chat/presentation/widgets/upload_progress.dart
import 'dart:async';

import 'package:dio/dio.dart';

enum UploadStatus { preparing, uploading, success, failed, cancelled }

class UploadProgress {
  final String fileId;
  final String fileName;
  final String fileType;
  final double progress;
  final UploadStatus status;
  final StreamController<double>? progressController;
  final StreamController<UploadStatus>? statusController;
  final CancelToken? cancelToken;
  final int retryCount;

  UploadProgress({
    required this.fileId,
    required this.fileName,
    required this.fileType,
    this.progress = 0.0,
    this.status = UploadStatus.preparing,
    this.progressController,
    this.statusController,
    this.cancelToken,
    this.retryCount = 0,
  });

  // Add copyWith method
  UploadProgress copyWith({
    double? progress,
    UploadStatus? status,
    int? retryCount,
  }) {
    return UploadProgress(
      fileId: fileId,
      fileName: fileName,
      fileType: fileType,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      progressController: progressController,
      statusController: statusController,
      cancelToken: cancelToken,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
