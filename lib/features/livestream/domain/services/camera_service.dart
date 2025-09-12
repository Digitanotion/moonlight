import 'package:flutter/widgets.dart';

abstract class CameraService {
  Future<bool> initialize(); // request permissions + set up controller
  Widget buildPreview(); // returns a live preview widget
  bool get isInitialized;
  Future<void> start(); // startPreview if needed
  Future<void> stop(); // stopPreview if needed
  Future<void> dispose();
}
