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

  test('a guest whose call dropped is hidden until they rejoin', () {
    meter.setGoneForTest(11, true);
    expect(meter.isGone(11), isTrue);
    meter.setGoneForTest(11, false);
    expect(meter.isGone(11), isFalse);
    meter.setGoneForTest(12, true);
    meter.reset();
    expect(meter.isGone(12), isFalse);
  });

  test('a silent watch-only connection doesn\'t hide my talking', () {
    // Guest: the box connection hears me, the pre-loaded streams don't.
    meter.feedVolumesForTest(const [AudioVolumeInfo(uid: 0, volume: 100)]);
    meter.feedVolumesForTest(const [AudioVolumeInfo(uid: 0, volume: 0)]);
    expect(meter.isSpeaking(0), isTrue);
    expect(meter.levelOf(0).value, greaterThan(0.3));
  });

  test('my report labelled with my own uid still counts as me', () {
    meter.feedVolumesForTest(const [
      AudioVolumeInfo(uid: 555, volume: 90),
    ], localUid: 555);
    expect(meter.isSpeaking(0), isTrue);
  });

  test('camera off shows until it comes back on', () {
    meter.setCamOff(21, true);
    expect(meter.isCamOff(21), isTrue);
    meter.setCamOff(21, false);
    expect(meter.isCamOff(21), isFalse);
    meter.setCamOff(22, true);
    meter.reset();
    expect(meter.isCamOff(22), isFalse);
  });
}
