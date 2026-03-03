// lib/features/chat/presentation/widgets/upload_progress_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/chat/presentation/widgets/upload_progress.dart';

class UploadProgressWidget extends StatefulWidget {
  final String fileId;
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
    required this.fileId,
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

class _UploadProgressWidgetState extends State<UploadProgressWidget>
    with SingleTickerProviderStateMixin {
  late double _progress;
  late UploadStatus _status;
  StreamSubscription<double>? _progressSubscription;
  StreamSubscription<UploadStatus>? _statusSubscription;
  late AnimationController _fadeController;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
    _status = widget.initialStatus;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();

    _setupStreams();
  }

  void _setupStreams() {
    if (widget.progressStream != null) {
      _progressSubscription = widget.progressStream!.listen(
        (progress) {
          if (mounted && !_isRemoving) {
            setState(() {
              _progress = progress.clamp(0.0, 1.0);
              if (_status == UploadStatus.preparing && progress > 0) {
                _status = UploadStatus.uploading;
              }
            });
          }
        },
        onError: (error) {
          if (mounted && !_isRemoving) {
            setState(() => _status = UploadStatus.failed);
          }
        },
      );
    }

    if (widget.statusStream != null) {
      _statusSubscription = widget.statusStream!.listen(
        (status) {
          if (mounted && !_isRemoving) {
            setState(() => _status = status);

            // Auto-remove after success after 1 second
            if (status == UploadStatus.success) {
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted &&
                    _status == UploadStatus.success &&
                    !_isRemoving) {
                  _handleCancel();
                }
              });
            }
          }
        },
        onError: (error) {
          if (mounted && !_isRemoving) {
            setState(() => _status = UploadStatus.failed);
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _statusSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    if (_isRemoving) return;

    setState(() => _isRemoving = true);

    _fadeController.reverse().then((_) {
      if (mounted) {
        widget.onCancel?.call();
      }
    });
  }

  void _handleRetry() async {
    // Show preparing state immediately
    if (mounted) {
      setState(() {
        _status = UploadStatus.preparing;
        _progress = 0.0;
        _isRemoving = false;
      });
    }

    // Add debug log
    debugPrint(
      '🔄 Retry clicked for file: ${widget.fileName} (${widget.fileId})',
    );

    // Small delay to show preparing state
    await Future.delayed(const Duration(milliseconds: 100));

    // Call the retry callback
    if (mounted && widget.onRetry != null) {
      widget.onRetry!();
    }
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
        return 'Uploaded ✓';
      case UploadStatus.failed:
        return 'Upload failed';
      case UploadStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: SizeTransition(
        sizeFactor: _fadeController,
        axisAlignment: -1.0,
        child: Container(
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
                  // File icon with animated status
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFileIcon(),
                      color: _getStatusColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _getStatusIcon(),
                      key: ValueKey(_status),
                      color: _getStatusColor(),
                      size: 20,
                    ),
                  ),

                  // Action buttons
                  if (_status == UploadStatus.failed)
                    IconButton(
                      onPressed: _handleRetry,
                      icon: const Icon(Icons.refresh, size: 20),
                      color: AppColors.primary_,
                      tooltip: 'Retry',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (_status == UploadStatus.uploading ||
                      _status == UploadStatus.preparing)
                    IconButton(
                      onPressed: _handleCancel,
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.textSecondary,
                      tooltip: 'Cancel',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (_status == UploadStatus.success)
                    const SizedBox(width: 36), // Maintain spacing
                  if (_status == UploadStatus.cancelled)
                    const SizedBox(width: 36),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar and status
              if (_status == UploadStatus.uploading ||
                  _status == UploadStatus.preparing)
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: AppColors.card,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getStatusColor(),
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getStatusText(),
                          style: TextStyle(
                            color: _getStatusColor(),
                            fontSize: 12,
                          ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 12,
                        fontWeight: _status == UploadStatus.success
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                    if (_status == UploadStatus.failed)
                      TextButton(
                        onPressed: _handleRetry,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            color: AppColors.primary_,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    final type = widget.fileType.toLowerCase();
    if (type.contains('image')) return Icons.image;
    if (type.contains('video')) return Icons.videocam;
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('audio')) return Icons.audiotrack;
    return Icons.insert_drive_file;
  }
}
