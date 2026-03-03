// lib/features/chat/presentation/services/upload_manager.dart
import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:moonlight/features/chat/presentation/widgets/upload_progress.dart';

class UploadTask {
  final String fileId;
  final String conversationUuid;
  final File file;
  final String? body;
  final String? replyToUuid;
  final String fileName;
  final String fileType;

  CancelToken? cancelToken;
  Completer<Message>? completer;
  int retryCount = 0;
  UploadStatus status = UploadStatus.preparing;
  double progress = 0.0;

  final StreamController<double> progressController =
      StreamController<double>.broadcast();
  final StreamController<UploadStatus> statusController =
      StreamController<UploadStatus>.broadcast();

  UploadTask({
    required this.fileId,
    required this.conversationUuid,
    required this.file,
    this.body,
    this.replyToUuid,
    required this.fileName,
    required this.fileType,
  });

  void dispose() {
    progressController.close();
    statusController.close();
    cancelToken?.cancel();
  }

  void updateProgress(double value) {
    progress = value;
    if (!progressController.isClosed) {
      progressController.add(value);
    }
  }

  void updateStatus(UploadStatus newStatus) {
    status = newStatus;
    if (!statusController.isClosed) {
      statusController.add(newStatus);
    }
  }
}

class UploadManager {
  final Map<String, UploadTask> _tasks = {};
  final StreamController<UploadTask> _taskAddedController =
      StreamController.broadcast();
  final StreamController<UploadTask> _taskRemovedController =
      StreamController.broadcast();
  final StreamController<UploadTask> _taskUpdatedController =
      StreamController.broadcast();

  Stream<UploadTask> get onTaskAdded => _taskAddedController.stream;
  Stream<UploadTask> get onTaskRemoved => _taskRemovedController.stream;
  Stream<UploadTask> get onTaskUpdated => _taskUpdatedController.stream;

  List<UploadTask> get activeTasks => _tasks.values.toList();

  String addTask({
    required String conversationUuid,
    required File file,
    String? body,
    String? replyToUuid,
  }) {
    final fileId =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.hashCode}';
    final fileName = file.path.split('/').last;
    final fileType = _getFileType(file);

    final task = UploadTask(
      fileId: fileId,
      conversationUuid: conversationUuid,
      file: file,
      body: body,
      replyToUuid: replyToUuid,
      fileName: fileName,
      fileType: fileType,
    );

    _tasks[fileId] = task;
    _taskAddedController.add(task);

    return fileId;
  }

  UploadTask? getTask(String fileId) => _tasks[fileId];

  // Get as Map for backward compatibility
  Map<String, UploadProgress> get uploadsMap {
    return _tasks.map(
      (key, task) => MapEntry(
        key,
        UploadProgress(
          fileId: task.fileId,
          fileName: task.fileName,
          fileType: task.fileType,
          progress: task.progress,
          status: task.status,
          progressController: task.progressController,
          statusController: task.statusController,
          cancelToken: task.cancelToken,
          retryCount: task.retryCount,
        ),
      ),
    );
  }

  // Get as List for easier iteration
  List<UploadProgress> get uploadsList {
    return _tasks.values
        .map(
          (task) => UploadProgress(
            fileId: task.fileId,
            fileName: task.fileName,
            fileType: task.fileType,
            progress: task.progress,
            status: task.status,
            progressController: task.progressController,
            statusController: task.statusController,
            cancelToken: task.cancelToken,
            retryCount: task.retryCount,
          ),
        )
        .toList();
  }

  // Update a task and return both formats if needed
  void updateTask(
    String fileId, {
    double? progress,
    UploadStatus? status,
    int? retryCount,
  }) {
    final task = _tasks[fileId];
    if (task != null) {
      if (progress != null) task.updateProgress(progress);
      if (status != null) task.updateStatus(status);
      if (retryCount != null) task.retryCount = retryCount;
      _taskUpdatedController.add(task);
    }
  }

  void removeTask(String fileId) {
    final task = _tasks.remove(fileId);
    if (task != null) {
      task.dispose();
      _taskRemovedController.add(task);
    }
  }

  void clearCompleted() {
    final toRemove = _tasks.values
        .where(
          (t) =>
              t.status == UploadStatus.success ||
              t.status == UploadStatus.cancelled,
        )
        .map((t) => t.fileId)
        .toList();

    for (final fileId in toRemove) {
      removeTask(fileId);
    }
  }

  String _getFileType(File file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif')) {
      return 'Image';
    } else if (path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi')) {
      return 'Video';
    } else if (path.endsWith('.pdf')) {
      return 'PDF Document';
    } else if (path.endsWith('.mp3') || path.endsWith('.wav')) {
      return 'Audio';
    }
    return 'File';
  }

  void dispose() {
    for (final task in _tasks.values) {
      task.dispose();
    }
    _tasks.clear();
    _taskAddedController.close();
    _taskRemovedController.close();
    _taskUpdatedController.close();
  }
}
