import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/services/camera_service.dart';

class RealCameraService implements CameraService {
  CameraController? _controller;

  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  Future<bool> initialize() async {
    // Ask permission
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) return false;

    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false, // audio handled separately by Record
    );

    await _controller!.initialize();
    return true;
  }

  @override
  Future<void> start() async {
    if (_controller != null && !_controller!.value.isPreviewPaused) {
      // already running
      return;
    }
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.resumePreview();
  }

  @override
  Future<void> stop() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.pausePreview();
  }

  @override
  Widget buildPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CameraPreview(_controller!),
    );
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
