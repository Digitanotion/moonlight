import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ringtone_native_method_channel.dart';

abstract class RingtoneNativePlatform extends PlatformInterface {
  /// Constructs a RingtoneNativePlatform.
  RingtoneNativePlatform() : super(token: _token);

  static final Object _token = Object();

  static RingtoneNativePlatform _instance = MethodChannelRingtoneNative();

  /// The default instance of [RingtoneNativePlatform] to use.
  ///
  /// Defaults to [MethodChannelRingtoneNative].
  static RingtoneNativePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RingtoneNativePlatform] when
  /// they register themselves.
  static set instance(RingtoneNativePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
