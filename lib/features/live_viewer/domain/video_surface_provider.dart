import 'package:flutter/widgets.dart';

/// If a repository can render live video, it implements this.
abstract class VideoSurfaceProvider {
  Widget buildHostVideo();
  Widget? buildLocalPreview();
}
