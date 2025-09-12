import 'dart:async';
import 'dart:io';

import 'package:moonlight/features/livestream/domain/services/audio_test_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class RecordAudioTestService implements AudioTestService {
  final _recorder = AudioRecorder();
  final _levelCtl = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _sub;
  bool _running = false;

  String? _currentPath; // 👈 remember the temp file path

  @override
  bool get isRunning => _running;

  @override
  Stream<double> get levelStream => _levelCtl.stream;

  @override
  Future<bool> initialize() async {
    final mic = await Permission.microphone.request();
    return mic.isGranted;
  }

  @override
  Future<void> start() async {
    if (_running) return;
    if (!await _recorder.hasPermission()) return;

    final tmpDir = await getTemporaryDirectory();
    _currentPath =
        '${tmpDir.path}/audio_test_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      RecordConfig(encoder: AudioEncoder.aacLc),
      path: _currentPath!,
    );

    _sub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amp) {
          final normalized = ((amp.current + 45) / 45).clamp(0.0, 1.0);
          _levelCtl.add(normalized);
        });
    _running = true;
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
    _running = false;
  }

  /// 👇 New: stop and delete the temp file
  Future<void> stopAndClean() async {
    await stop();
    if (_currentPath != null) {
      final file = File(_currentPath!);
      if (await file.exists()) {
        await file.delete();
      }
      _currentPath = null;
    }
  }

  @override
  Future<void> dispose() async {
    await stopAndClean();
    await _levelCtl.close();
  }
}
