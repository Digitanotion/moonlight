abstract class AudioTestService {
  Future<bool> initialize(); // asks mic permission
  Stream<double> get levelStream; // normalized 0.0 - 1.0
  Future<void> start(); // begin monitoring
  Future<void> stop(); // stop monitoring
  Future<void> stopAndClean();
  bool get isRunning;
  Future<void> dispose();
}
