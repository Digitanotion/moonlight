// Add this listenable so UI can switch between fallback and video.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

abstract class VideoSurfaceProvider {
  /// Emits true when a remote host video is available.
  ValueListenable<bool> get hostHasVideo;

  /// Full-bleed host video widget.
  Widget buildHostVideo();

  /// Optional local preview bubble when co-hosting.
  Widget? buildLocalPreview();
}
