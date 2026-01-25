// features/chat/presentation/widgets/upload_progress_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/chat/presentation/widgets/upload_progress.dart';

class UploadProgressWidget extends StatefulWidget {
  final String fileName;
  final String fileType;
  final double initialProgress;
  final UploadStatus initialStatus;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final Stream<double>? progressStream;
  final Stream<UploadStatus>? statusStream;

  const UploadProgressWidget({
    super.key,
    required this.fileName,
    required this.fileType,
    this.initialProgress = 0.0,
    this.initialStatus = UploadStatus.preparing,
    this.onRetry,
    this.onCancel,
    this.progressStream,
    this.statusStream,
  });

  @override
  State<UploadProgressWidget> createState() => _UploadProgressWidgetState();
}

class _UploadProgressWidgetState extends State<UploadProgressWidget> {
  late double _progress;
  late UploadStatus _status;
  StreamSubscription<double>? _progressSubscription;
  StreamSubscription<UploadStatus>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
    _status = widget.initialStatus;

    if (widget.progressStream != null) {
      _progressSubscription = widget.progressStream!.listen((progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
          });
        }
      });
    }

    if (widget.statusStream != null) {
      _statusSubscription = widget.statusStream!.listen((status) {
        if (mounted) {
          setState(() {
            _status = status;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  IconData _getStatusIcon() {
    switch (_status) {
      case UploadStatus.preparing:
        return Icons.access_time;
      case UploadStatus.uploading:
        return Icons.cloud_upload;
      case UploadStatus.success:
        return Icons.check_circle;
      case UploadStatus.failed:
        return Icons.error_outline;
      case UploadStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor() {
    switch (_status) {
      case UploadStatus.preparing:
        return AppColors.textSecondary;
      case UploadStatus.uploading:
        return AppColors.primary_;
      case UploadStatus.success:
        return Colors.green;
      case UploadStatus.failed:
        return Colors.red;
      case UploadStatus.cancelled:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText() {
    switch (_status) {
      case UploadStatus.preparing:
        return 'Preparing...';
      case UploadStatus.uploading:
        return 'Uploading...';
      case UploadStatus.success:
        return 'Uploaded';
      case UploadStatus.failed:
        return 'Upload failed';
      case UploadStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // File icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getFileIcon(), color: _getStatusColor(), size: 20),
              ),
              const SizedBox(width: 12),

              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fileName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.fileType,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Status icon
              Icon(_getStatusIcon(), color: _getStatusColor(), size: 20),

              // Action buttons
              if (_status == UploadStatus.failed)
                IconButton(
                  onPressed: widget.onRetry,
                  icon: Icon(
                    Icons.refresh,
                    color: AppColors.primary_,
                    size: 20,
                  ),
                  tooltip: 'Retry',
                ),
              if (_status == UploadStatus.uploading ||
                  _status == UploadStatus.preparing)
                IconButton(
                  onPressed: widget.onCancel,
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Cancel',
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar and status
          if (_status == UploadStatus.uploading ||
              _status == UploadStatus.preparing)
            Column(
              children: [
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppColors.card,
                  valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getStatusText(),
                      style: TextStyle(color: _getStatusColor(), fontSize: 12),
                    ),
                    Text(
                      '${(_progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Text(
              _getStatusText(),
              style: TextStyle(color: _getStatusColor(), fontSize: 12),
            ),
        ],
      ),
    );
  }

  IconData _getFileIcon() {
    if (widget.fileType.toLowerCase().contains('image')) {
      return Icons.image;
    } else if (widget.fileType.toLowerCase().contains('video')) {
      return Icons.videocam;
    } else if (widget.fileType.toLowerCase().contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (widget.fileType.toLowerCase().contains('audio')) {
      return Icons.audiotrack;
    } else {
      return Icons.insert_drive_file;
    }
  }
}
