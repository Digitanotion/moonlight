import 'package:flutter_test/flutter_test.dart';
import 'package:ringtone_native/ringtone_native.dart';
import 'package:ringtone_native/ringtone_native_platform_interface.dart';
import 'package:ringtone_native/ringtone_native_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockRingtoneNativePlatform
    with MockPlatformInterfaceMixin
    implements RingtoneNativePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final RingtoneNativePlatform initialPlatform = RingtoneNativePlatform.instance;

  test('$MethodChannelRingtoneNative is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRingtoneNative>());
  });

  test('getPlatformVersion', () async {
    RingtoneNative ringtoneNativePlugin = RingtoneNative();
    MockRingtoneNativePlatform fakePlatform = MockRingtoneNativePlatform();
    RingtoneNativePlatform.instance = fakePlatform;

    expect(await ringtoneNativePlugin.getPlatformVersion(), '42');
  });
}
