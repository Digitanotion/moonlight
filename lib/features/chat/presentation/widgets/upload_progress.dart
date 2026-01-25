// upload_progress.dart
import 'dart:async';

enum UploadStatus { preparing, uploading, success, failed, cancelled }

class UploadProgress {
  final String fileId;
  final String fileName;
  final String fileType;
  double progress;
  UploadStatus status;
  final StreamController<double>? progressController;
  final StreamController<UploadStatus>? statusController;

  UploadProgress({
    required this.fileId,
    required this.fileName,
    required this.fileType,
    this.progress = 0.0,
    this.status = UploadStatus.preparing,
    this.progressController,
    this.statusController,
  });

  // Add copyWith method
  UploadProgress copyWith({double? progress, UploadStatus? status}) {
    return UploadProgress(
      fileId: fileId,
      fileName: fileName,
      fileType: fileType,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      progressController: progressController,
      statusController: statusController,
    );
  }
}
