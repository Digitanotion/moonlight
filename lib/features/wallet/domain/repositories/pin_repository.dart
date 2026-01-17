abstract class PinRepository {
  Future<Map<String, dynamic>> setPin({
    required String pin,
    required String confirmPin,
  });

  Future<Map<String, dynamic>> resetPin({
    required String currentPin,
    required String newPin,
    required String confirmNewPin,
  });

  Future<Map<String, dynamic>> verifyPin(String pin);

  Future<Map<String, dynamic>> getPinStatus();

  Future<Map<String, dynamic>> unlockPin({
    required String method,
    String? securityAnswer,
  });

  Future<Map<String, dynamic>> getPinHistory({
    int page = 1,
    int perPage = 10,
    String? action,
  });
}
