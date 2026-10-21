import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/core/services/live_audio_meter.dart';

void main() {
  final meter = LiveAudioMeter.instance;
  setUp(meter.reset);

  test('my mic report and everyone else\'s report don\'t cancel out', () {
    // Agora sends two separate reports: one for me (uid 0), one for others.
    meter.feedVolumesForTest(const [AudioVolumeInfo(uid: 0, volume: 90)]);
    meter.feedVolumesForTest(const [AudioVolumeInfo(uid: 42, volume: 80)]);

    expect(meter.isSpeaking(0), isTrue);
    expect(meter.isSpeaking(42), isTrue);
    expect(meter.levelOf(42).value, greaterThan(0));
  });

  test('quiet speakers are not shown as talking', () {
    meter.feedVolumesForTest(const [AudioVolumeInfo(uid: 7, volume: 3)]);
    expect(meter.isSpeaking(7), isFalse);
  });

  test('muting stops the wave and shows muted', () {
    meter.feedVolumesForTest(const [AudioVolumeInfo(uid: 9, volume: 100)]);
    expect(meter.isSpeaking(9), isTrue);
    meter.setMutedForTest(9, true);
    expect(meter.isMuted(9), isTrue);
    expect(meter.isSpeaking(9), isFalse);
    expect(meter.levelOf(9).value, 0);
  });
}
