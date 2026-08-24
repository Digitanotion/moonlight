
import 'ringtone_native_platform_interface.dart';

class RingtoneNative {
  Future<String?> getPlatformVersion() {
    return RingtoneNativePlatform.instance.getPlatformVersion();
  }
}
