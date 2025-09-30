/// lib/features/live_viewer/domain/video_surface_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

abstract class VideoSurfaceProvider {
  /// Host video presence + surface
  ValueListenable<bool> get hostHasVideo;
  Widget buildHostVideo();

  /// Guest video presence + surface (when you are not the guest)
  ValueListenable<bool> get guestHasVideo;
  Widget buildGuestVideo();

  /// Local preview bubble/surface (when you are the guest)
  Widget? buildLocalPreview();

  /// Guest controls
  Future<void> setMicEnabled(bool on);
  Future<void> setCamEnabled(bool on);
}
