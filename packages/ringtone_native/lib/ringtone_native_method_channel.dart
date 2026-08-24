import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ringtone_native_platform_interface.dart';

/// An implementation of [RingtoneNativePlatform] that uses method channels.
class MethodChannelRingtoneNative extends RingtoneNativePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ringtone_native');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
