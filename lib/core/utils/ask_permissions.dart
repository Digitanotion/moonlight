// lib/core/utils/ask_permissions.dart
import 'package:permission_handler/permission_handler.dart';

Future<void> askCameraAndMic() async {
  final statuses = await [Permission.camera, Permission.microphone].request();
  // Optional: simple assert/guard
  if (statuses[Permission.camera]?.isGranted != true ||
      statuses[Permission.microphone]?.isGranted != true) {
    throw Exception('Camera/Microphone permission not granted');
  }
}
